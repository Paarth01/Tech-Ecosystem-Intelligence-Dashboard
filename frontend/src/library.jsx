import { createContext, useContext, useEffect, useMemo, useRef, useState } from "react";
import { api } from "./api";
import { useAuth } from "./auth";

const LibraryContext = createContext(null);
export const MAX_COMPARE = 4;

// The fields we keep when an article is saved or compared.
const pick = (a) => ({
  title: a.title, url: a.url, source: a.source, description: a.description,
  meta: a.meta, author: a.author, date: a.date, tags: a.tags || [],
});

export function LibraryProvider({ children }) {
  const { user } = useAuth();
  const userId = user?.id;
  const [saved, setSaved] = useState([]);
  const [selected, setSelectedState] = useState([]);

  // Always holds the current user, so a slow response for a previous user can be recognised.
  const currentUser = useRef(userId);
  currentUser.current = userId;

  // Load this user's saved articles and compare selection whenever the user changes.
  useEffect(() => {
    setSaved([]);                       // never show the previous user's list, not even briefly
    if (!userId) {
      setSelectedState([]);
      return undefined;
    }
    let cancelled = false;              // ignore the response if the user changes before it arrives
    api.get("/saved_articles").then((list) => { if (!cancelled) setSaved(list); }).catch(() => {});
    try {
      setSelectedState(JSON.parse(sessionStorage.getItem(`compare:${userId}`)) || []);
    } catch {
      setSelectedState([]);
    }
    return () => { cancelled = true; };
  }, [userId]);

  const setSelected = (items) => {
    setSelectedState(items);
    if (userId) sessionStorage.setItem(`compare:${userId}`, JSON.stringify(items));
  };

  const savedByUrl = useMemo(() => new Map(saved.map((a) => [a.url, a])), [saved]);

  const value = {
    saved,
    isSaved: (url) => savedByUrl.has(url),
    async toggleSave(article) {
      const owner = userId;
      const existing = savedByUrl.get(article.url);
      if (existing) {
        await api.del(`/saved_articles/${existing.id}`);
        if (currentUser.current !== owner) return;
        setSaved((list) => list.filter((a) => a.id !== existing.id));
      } else {
        const created = await api.post("/saved_articles", { article: pick(article) });
        if (currentUser.current !== owner) return;    // someone else is signed in now
        setSaved((list) => [created, ...list.filter((a) => a.url !== created.url)]);
      }
    },
    selected,
    isSelected: (url) => selected.some((a) => a.url === url),
    toggleSelected(article) {
      if (selected.some((a) => a.url === article.url)) {
        setSelected(selected.filter((a) => a.url !== article.url));
      } else if (selected.length < MAX_COMPARE) {
        setSelected([...selected, pick(article)]);
      }
    },
    clearSelected: () => setSelected([]),
  };

  return <LibraryContext.Provider value={value}>{children}</LibraryContext.Provider>;
}

export const useLibrary = () => useContext(LibraryContext);
