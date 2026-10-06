import { useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../api";
import Markdown from "../components/Markdown";
import { Empty, ErrorNote } from "../components/PageState";
import { sourceInfo } from "../dashboardStore";
import { useLibrary } from "../library";

export default function Compare() {
  const { selected, toggleSelected } = useLibrary();
  const [result, setResult] = useState(null);      // { markdown, ai, note, items }
  const [generating, setGenerating] = useState(false);
  const [saving, setSaving] = useState(false);
  const [savedId, setSavedId] = useState(null);
  const [error, setError] = useState("");

  const generate = async () => {
    setGenerating(true);
    setError("");
    setSavedId(null);
    try {
      const data = await api.post("/comparisons/generate", { items: selected });
      setResult({ ...data, items: selected });
    } catch (e) {
      setError(e.message);
    } finally {
      setGenerating(false);
    }
  };

  const save = async () => {
    setSaving(true);
    setError("");
    try {
      const created = await api.post("/comparisons", {
        items: result.items, result: result.markdown, ai_generated: result.ai,
      });
      setSavedId(created.id);
    } catch (e) {
      setError(e.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Compare articles</h1>
          <p className="muted">Pick two to four items from the dashboard, research or saved pages, then generate a side-by-side comparison.</p>
        </div>
      </div>

      {selected.length === 0 && !result ? (
        <Empty title="No articles selected">
          Choose Compare on a few articles in the <Link to="/">dashboard</Link>, <Link to="/research">research</Link> or <Link to="/saved">saved</Link> pages.
        </Empty>
      ) : (
        <div className="card">
          <h2 className="card-title">Selected ({selected.length}/4)</h2>
          <ul className="rows">
            {selected.map((a) => (
              <li key={a.url} className="row">
                <div className="row-main">
                  <a href={a.url} target="_blank" rel="noopener noreferrer">{a.title}</a>
                  <span className="muted small">{sourceInfo(a.source).label}{a.meta ? ` · ${a.meta}` : ""}</span>
                </div>
                <button className="btn btn-ghost btn-sm" onClick={() => toggleSelected(a)}>Remove</button>
              </li>
            ))}
          </ul>
          <div className="form-actions">
            <button className="btn btn-primary" onClick={generate} disabled={selected.length < 2 || generating}>
              {generating ? "Comparing…" : result ? "Compare again" : "Generate comparison"}
            </button>
            {selected.length < 2 && <span className="muted small">Select at least two articles.</span>}
          </div>
        </div>
      )}

      {error && <div className="section"><ErrorNote message={error} /></div>}

      {result && (
        <section className="section">
          <div className="page-head tight">
            <h2 className="section-title">Comparison</h2>
            {savedId ? (
              <span className="muted">Saved. <Link to={`/comparisons/${savedId}`}>View it</Link></span>
            ) : (
              <button className="btn btn-primary btn-sm" onClick={save} disabled={saving}>
                {saving ? "Saving…" : "Save comparison"}
              </button>
            )}
          </div>
          {result.note && <p className="note">{result.note}</p>}
          <div className="card"><Markdown>{result.markdown}</Markdown></div>
        </section>
      )}
    </>
  );
}
