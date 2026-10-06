import { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { SOURCES, loadDashboard, sourceInfo } from "../dashboardStore";
import { useLibrary } from "../library";

// Ctrl+K: search today's trending items and your saved articles, or start a research search.
export default function CommandPalette({ onClose }) {
  const navigate = useNavigate();
  const { saved } = useLibrary();
  const [query, setQuery] = useState("");
  const [cursor, setCursor] = useState(0);
  const [feedItems, setFeedItems] = useState([]);
  const inputRef = useRef(null);

  // Move focus into the dialog, and give it back to whatever had it when the dialog closes.
  useEffect(() => {
    const previous = document.activeElement;
    inputRef.current?.focus();
    return () => previous?.focus?.();
  }, []);

  useEffect(() => {
    loadDashboard().then((d) => setFeedItems(SOURCES.flatMap((s) => d.feeds[s.key] || []))).catch(() => {});
  }, []);

  const rows = useMemo(() => {
    const q = query.trim();
    if (q.length < 2) return [];
    const needle = q.toLowerCase();
    const matches = [...saved, ...feedItems]
      .filter((i) => `${i.title} ${i.description || ""} ${(i.tags || []).join(" ")}`.toLowerCase().includes(needle))
      .filter((item, idx, all) => all.findIndex((o) => o.url === item.url) === idx)
      .slice(0, 8);
    return [{ type: "research", q }, ...matches.map((item) => ({ type: "item", item }))];
  }, [query, saved, feedItems]);

  const run = (row) => {
    if (!row) return;
    if (row.type === "research") navigate(`/research?q=${encodeURIComponent(row.q)}`);
    else window.open(row.item.url, "_blank", "noopener,noreferrer");
    onClose();
  };

  const onKeyDown = (e) => {
    if (e.key === "Escape") onClose();
    else if (e.key === "Tab") e.preventDefault();        // keep focus inside the dialog
    else if (e.key === "ArrowDown") { e.preventDefault(); setCursor((c) => Math.min(c + 1, rows.length - 1)); }
    else if (e.key === "ArrowUp") { e.preventDefault(); setCursor((c) => Math.max(c - 1, 0)); }
    else if (e.key === "Enter") { e.preventDefault(); run(rows[cursor]); }
  };

  return (
    <div className="overlay" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className="palette" role="dialog" aria-modal="true" aria-label="Search">
        <input
          ref={inputRef}
          className="palette-input"
          value={query}
          onChange={(e) => { setQuery(e.target.value); setCursor(0); }}
          onKeyDown={onKeyDown}
          placeholder="Search trending items, or type a project idea…"
          aria-label="Search"
        />
        <ul className="palette-list">
          {rows.length === 0 && (
            <li className="palette-hint">Type at least 2 characters. Press Enter to research an idea across the web.</li>
          )}
          {rows.map((row, i) => (
            <li key={row.type === "research" ? "research" : row.item.url}>
              <button tabIndex={-1} className={`palette-row ${i === cursor ? "active" : ""}`}
                      onMouseEnter={() => setCursor(i)} onClick={() => run(row)}>
                {row.type === "research" ? (
                  <span>Research “{row.q}” on GitHub, Dev.to, Reddit and Stack Overflow</span>
                ) : (
                  <>
                    <span className="truncate">{row.item.title}</span>
                    <span className="muted small">{sourceInfo(row.item.source).label}</span>
                  </>
                )}
              </button>
            </li>
          ))}
        </ul>
        <div className="palette-foot muted small">↑↓ to move · Enter to open · Esc to close</div>
      </div>
    </div>
  );
}
