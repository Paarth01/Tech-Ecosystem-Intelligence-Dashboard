import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../api";
import { Empty, ErrorNote, Loading } from "../components/PageState";
import { sourceInfo } from "../dashboardStore";
import { formatDate } from "../format";

const PAGE = 20;

export default function Comparisons() {
  const [list, setList] = useState(null);
  const [visible, setVisible] = useState(PAGE);
  const [error, setError] = useState("");

  useEffect(() => { api.get("/comparisons").then(setList).catch((e) => setError(e.message)); }, []);

  const remove = async (c) => {
    if (!window.confirm(`Delete “${c.title}”?`)) return;
    try {
      await api.del(`/comparisons/${c.id}`);
      setList((l) => l.filter((x) => x.id !== c.id));
    } catch (e) {
      setError(e.message);
    }
  };

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Saved comparisons</h1>
          <p className="muted">Your previous comparisons. They are private to your account.</p>
        </div>
      </div>

      {error && <ErrorNote message={error} />}
      {!list && !error && <Loading />}
      {list && list.length === 0 && (
        <Empty title="No saved comparisons">Select articles to <Link to="/compare">compare</Link> and save the result.</Empty>
      )}
      {list && list.length > 0 && (
        <ul className="rows card">
          {list.slice(0, visible).map((c) => (
            <li key={c.id} className="row">
              <div className="row-main">
                <Link to={`/comparisons/${c.id}`} className="row-title">{c.title}</Link>
                <span className="muted small">
                  {formatDate(c.created_at)} · {c.item_count} articles · {c.sources.map((s) => sourceInfo(s).label).join(", ")}
                  {c.ai_generated ? " · AI summary" : ""}
                </span>
              </div>
              <button className="btn btn-ghost btn-sm danger" onClick={() => remove(c)}>Delete</button>
            </li>
          ))}
        </ul>
      )}
      {list && list.length > visible && (
        <div className="show-more">
          <button className="btn btn-secondary" onClick={() => setVisible(visible + PAGE)}>Show more ({list.length - visible} more)</button>
        </div>
      )}
    </>
  );
}
