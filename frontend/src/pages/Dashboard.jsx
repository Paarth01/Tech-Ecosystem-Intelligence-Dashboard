import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import ArticleCard from "../components/ArticleCard";
import TrendBadge from "../components/TrendBadge";
import { Empty, ErrorNote, Loading } from "../components/PageState";
import { SOURCES, loadDashboard } from "../dashboardStore";
import { timeAgo } from "../format";

const inEcosystem = (item, eco) => eco === "All" || (item.ecosystems || []).includes(eco);

export default function Dashboard() {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [eco, setEco] = useState("All");
  const [tab, setTab] = useState("github");
  const [refreshing, setRefreshing] = useState(false);
  const [notice, setNotice] = useState("");

  const load = () => {
    setError("");
    loadDashboard().then(setData).catch((e) => setError(e.message));
  };
  useEffect(() => { load(); }, []);

  // Refresh skips the server's cache. If it fails (for example, too many refreshes) the page keeps its data.
  const refresh = async () => {
    setRefreshing(true);
    setNotice("");
    try {
      setData(await loadDashboard(true));
    } catch (e) {
      setNotice(e.message);
    } finally {
      setRefreshing(false);
    }
  };

  if (error) return <ErrorNote message={error} onRetry={load} />;
  if (!data) return <Loading label="Gathering today's trends…" />;

  const topics = data.topics.filter((t) => inEcosystem(t, eco));
  const top = topics[0];
  const maxScore = top?.score || 1;
  const activeSource = SOURCES.find((s) => s.key === tab);
  const items = (data.feeds[tab] || []).filter((i) => inEcosystem(i, eco));

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Today in tech</h1>
          <p className="muted">
            {new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })}
            {" · "}What is gaining traction across five developer communities.
            {data.updated_at && <> Updated {timeAgo(data.updated_at)}.</>}
          </p>
        </div>
        <button className="btn btn-secondary btn-sm" onClick={refresh} disabled={refreshing}>
          {refreshing ? "Refreshing…" : "Refresh"}
        </button>
      </div>
      {notice && <p className="note" role="status">{notice}</p>}

      <div className="chips" role="group" aria-label="Filter by ecosystem">
        {data.ecosystems.map((name) => (
          <button key={name} className={`chip ${eco === name ? "active" : ""}`}
                  aria-pressed={eco === name} onClick={() => setEco(name)}>
            {name}
          </button>
        ))}
      </div>

      <section className="hero-grid">
        <div className="card spotlight">
          {top ? (
            <>
              <p className="muted small">Top topic right now</p>
              <h2 className="spotlight-name">{top.name} <TrendBadge trend={top.trend} /></h2>
              <p className="muted">
                Mentioned {top.mention_count} {top.mention_count === 1 ? "time" : "times"} across{" "}
                {top.source_count} {top.source_count === 1 ? "platform" : "platforms"}.
              </p>
              <ul className="plain-list">
                {top.mentions.slice(0, 3).map((m) => (
                  <li key={m.url}>
                    <a href={m.url} target="_blank" rel="noopener noreferrer">{m.title}</a>
                    <span className="muted small"> {m.source}</span>
                  </li>
                ))}
              </ul>
              <Link className="btn btn-secondary btn-sm" to={`/research?q=${encodeURIComponent(top.name)}`}>
                Research {top.name}
              </Link>
            </>
          ) : (
            <Empty title="No topics yet">Nothing matched this filter. Try another ecosystem.</Empty>
          )}
        </div>

        <div className="card">
          <h2 className="card-title">Trending technologies</h2>
          {topics.length === 0 && <p className="muted">Nothing to rank for this filter.</p>}
          <ol className="bars">
            {topics.slice(0, 6).map((t) => (
              <li key={t.tag}>
                <div className="bar-label"><span>{t.name} <TrendBadge trend={t.trend} /></span><span className="muted small">{t.score}</span></div>
                <div className="bar-track"><div className="bar-fill" style={{ width: `${Math.max(6, (t.score / maxScore) * 100)}%` }} /></div>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {topics.length > 1 && (
        <section className="section">
          <h2 className="section-title">All topics</h2>
          <div className="chips">
            {topics.slice(0, 24).map((t) => (
              <Link key={t.tag} className="chip" to={`/research?q=${encodeURIComponent(t.name)}`}
                    title={`Score ${t.score} · research ${t.name}`}>
                {t.name}
              </Link>
            ))}
          </div>
        </section>
      )}

      <section className="section">
        <h2 className="section-title">Community feeds</h2>
        <div className="tabs" role="tablist">
          {SOURCES.map((s) => {
            const count = (data.feeds[s.key] || []).filter((i) => inEcosystem(i, eco)).length;
            return (
              <button key={s.key} role="tab" aria-selected={tab === s.key}
                      className={`tab ${tab === s.key ? "active" : ""}`} onClick={() => setTab(s.key)}>
                {s.label} <span className="count">{count}</span>
              </button>
            );
          })}
        </div>

        {items.length > 0 ? (
          <div className="grid">{items.map((item) => <ArticleCard key={item.id + item.url} item={item} />)}</div>
        ) : data.unavailable.includes(tab) ? (
          <Empty title={`${activeSource.label} is unavailable right now`}>It may be limiting requests. Try Refresh in a few minutes.</Empty>
        ) : (
          <Empty title="Nothing here for this filter">Try another ecosystem or source.</Empty>
        )}
      </section>
    </>
  );
}
