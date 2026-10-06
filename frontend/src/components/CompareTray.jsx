import { useNavigate } from "react-router-dom";
import { MAX_COMPARE, useLibrary } from "../library";

// Floating bar that appears once at least one article is picked for comparison.
export default function CompareTray() {
  const { selected, toggleSelected, clearSelected } = useLibrary();
  const navigate = useNavigate();
  if (selected.length === 0) return null;

  return (
    <div className="tray" role="region" aria-label="Articles to compare">
      <div className="tray-items">
        {selected.map((a) => (
          <span key={a.url} className="tray-chip">
            <span className="truncate">{a.title}</span>
            <button onClick={() => toggleSelected(a)} aria-label={`Remove ${a.title}`}>×</button>
          </span>
        ))}
      </div>
      <div className="tray-actions">
        <span className="muted small">{selected.length}/{MAX_COMPARE} selected</span>
        <button className="btn btn-ghost btn-sm" onClick={clearSelected}>Clear</button>
        <button className="btn btn-primary btn-sm" disabled={selected.length < 2} onClick={() => navigate("/compare")}>
          {selected.length < 2 ? "Pick one more" : "Compare"}
        </button>
      </div>
    </div>
  );
}
