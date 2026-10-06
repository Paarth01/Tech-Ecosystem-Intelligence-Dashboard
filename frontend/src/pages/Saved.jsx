import { useState } from "react";
import { Link } from "react-router-dom";
import ArticleCard from "../components/ArticleCard";
import { Empty } from "../components/PageState";
import { useLibrary } from "../library";

const PAGE = 24;

export default function Saved() {
  const { saved } = useLibrary();
  const [filter, setFilter] = useState("");
  const [visible, setVisible] = useState(PAGE);
  const needle = filter.trim().toLowerCase();
  const shown = needle
    ? saved.filter((a) => `${a.title} ${a.description || ""} ${(a.tags || []).join(" ")}`.toLowerCase().includes(needle))
    : saved;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Saved articles</h1>
          <p className="muted">Only you can see this list. Tap Compare on two to four items to weigh them up.</p>
        </div>
        {saved.length > 0 && (
          <input className="input input-sm" value={filter} onChange={(e) => { setFilter(e.target.value); setVisible(PAGE); }}
                 placeholder="Filter saved…" aria-label="Filter saved articles" />
        )}
      </div>

      {saved.length === 0 ? (
        <Empty title="Nothing saved yet">
          Use Save on any article from the <Link to="/">dashboard</Link> or <Link to="/research">research</Link> page.
        </Empty>
      ) : shown.length === 0 ? (
        <Empty title="No matches">No saved article matches “{filter}”.</Empty>
      ) : (
        <>
          <div className="grid">{shown.slice(0, visible).map((a) => <ArticleCard key={a.id} item={a} />)}</div>
          {shown.length > visible && (
            <div className="show-more">
              <button className="btn btn-secondary" onClick={() => setVisible(visible + PAGE)}>Show more ({shown.length - visible} more)</button>
            </div>
          )}
        </>
      )}
    </>
  );
}
