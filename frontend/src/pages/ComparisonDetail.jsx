import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { api } from "../api";
import Markdown from "../components/Markdown";
import { ErrorNote, Loading } from "../components/PageState";
import { sourceInfo } from "../dashboardStore";
import { formatDate } from "../format";

export default function ComparisonDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [comparison, setComparison] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    api.get(`/comparisons/${id}`).then(setComparison).catch((e) => setError(e.message));
  }, [id]);

  const remove = async () => {
    if (!window.confirm("Delete this comparison?")) return;
    try {
      await api.del(`/comparisons/${id}`);
      navigate("/comparisons");
    } catch (e) {
      setError(e.message);
    }
  };

  if (error) return <><p><Link to="/comparisons">← All comparisons</Link></p><ErrorNote message={error} /></>;
  if (!comparison) return <Loading />;

  return (
    <>
      <p className="back"><Link to="/comparisons">← All comparisons</Link></p>
      <div className="page-head">
        <div>
          <h1>{comparison.title}</h1>
          <p className="muted">Saved {formatDate(comparison.created_at)}{comparison.ai_generated ? " · AI summary" : ""}</p>
        </div>
        <button className="btn btn-secondary btn-sm danger" onClick={remove}>Delete</button>
      </div>

      <div className="card"><Markdown>{comparison.result}</Markdown></div>

      <section className="section">
        <h2 className="section-title">Articles compared</h2>
        <ul className="rows card">
          {comparison.items.map((a) => (
            <li key={a.url} className="row">
              <div className="row-main">
                <a href={a.url} target="_blank" rel="noopener noreferrer" className="row-title">{a.title}</a>
                <span className="muted small">{sourceInfo(a.source).label}{a.meta ? ` · ${a.meta}` : ""}</span>
              </div>
            </li>
          ))}
        </ul>
      </section>
    </>
  );
}
