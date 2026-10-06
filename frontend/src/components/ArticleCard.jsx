import { useState } from "react";
import { MAX_COMPARE, useLibrary } from "../library";
import { sourceInfo } from "../dashboardStore";

export default function ArticleCard({ item }) {
  const { isSaved, toggleSave, isSelected, toggleSelected, selected } = useLibrary();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const source = sourceInfo(item.source);
  const saved = isSaved(item.url);
  const picked = isSelected(item.url);
  const full = !picked && selected.length >= MAX_COMPARE;

  const onSave = async () => {
    setBusy(true);
    setError("");
    try {
      await toggleSave(item);
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <article className="card article">
      <div className="article-top">
        <span className="badge"><span className="dot" style={{ background: source.dot }} />{source.label}</span>
        {item.date && <span className="muted small">{item.date}</span>}
      </div>

      <h3 className="article-title">
        <a href={item.url} target="_blank" rel="noopener noreferrer">{item.title}</a>
      </h3>
      {item.description && <p className="article-desc">{item.description}</p>}

      <div className="article-meta">
        {item.meta && <span className="meta-value">{item.meta}</span>}
        {item.tags?.slice(0, 3).map((t) => <span key={t} className="tag">{t}</span>)}
      </div>

      <div className="article-actions">
        <button className={`btn btn-sm ${saved ? "btn-primary-soft" : "btn-secondary"}`}
                onClick={onSave} disabled={busy} aria-pressed={saved}>
          {saved ? "Saved" : "Save"}
        </button>
        <button className={`btn btn-sm ${picked ? "btn-primary-soft" : "btn-secondary"}`}
                onClick={() => toggleSelected(item)} disabled={full} aria-pressed={picked}
                title={full ? `You can compare up to ${MAX_COMPARE} articles` : undefined}>
          {picked ? "Added to compare" : "Compare"}
        </button>
      </div>
      {error && <p className="error small">{error}</p>}
    </article>
  );
}
