import { api } from "./api";

// The dashboard is shared between the Dashboard page and the Ctrl+K palette. It is reused for a
// few minutes, then fetched again, so a tab left open for days doesn't keep showing old data.
export const MAX_AGE_MS = 5 * 60 * 1000;

let cached = null;
let loadedAt = 0;

export function loadDashboard(force = false) {
  if (!cached || force || Date.now() - loadedAt > MAX_AGE_MS) {
    loadedAt = Date.now();
    // Refresh is a POST: it makes the server skip its cache, so it must not be a plain link.
    cached = (force ? api.post("/dashboard/refresh") : api.get("/dashboard")).catch((err) => {
      cached = null;
      throw err;
    });
  }
  return cached;
}

export function clearDashboardCache() {
  cached = null;
}

export const SOURCES = [
  { key: "github", label: "GitHub", item: "GitHub", dot: "#6e56cf" },
  { key: "hackernews", label: "Hacker News", item: "HackerNews", dot: "#d9622b" },
  { key: "devto", label: "Dev.to", item: "Dev.to", dot: "#2f6fed" },
  { key: "lobsters", label: "Lobsters", item: "Lobsters", dot: "#b4323c" },
  { key: "stackoverflow", label: "Stack Overflow", item: "StackOverflow", dot: "#c77b0a" },
];

const EXTRA = { Reddit: { label: "Reddit", dot: "#cc4b1a" } };

// Display info for any source name that can appear on an item.
export function sourceInfo(name) {
  const found = SOURCES.find((s) => s.item === name);
  if (found) return found;
  return EXTRA[name] || { label: name || "Web", dot: "#6b7280" };
}
