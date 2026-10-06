import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { api } from "../api";
import ArticleCard from "../components/ArticleCard";
import { Empty, ErrorNote, Loading } from "../components/PageState";

const EXAMPLES = ["trello clone", "AI PDF summarizer", "habit tracker app", "realtime chat app", "expense tracker"];

export default function Research() {
  const [params, setParams] = useSearchParams();
  const q = params.get("q") || "";
  const [input, setInput] = useState(q);
  const [results, setResults] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    setInput(q);
    if (q.trim().length < 2) { setResults(null); return; }
    let cancelled = false;
    setLoading(true);
    setError("");
    api.get(`/search?q=${encodeURIComponent(q)}`)
      .then((data) => !cancelled && setResults(data))
      .catch((e) => !cancelled && setError(e.message))
      .finally(() => !cancelled && setLoading(false));
    return () => { cancelled = true; };
  }, [q]);

  const submit = (e) => {
    e.preventDefault();
    if (input.trim()) setParams({ q: input.trim() });
  };

  const total = results ? results.sections.reduce((n, s) => n + s.items.length, 0) : 0;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Research an idea</h1>
          <p className="muted">Search GitHub, Dev.to, Reddit and Stack Overflow at once to see what already exists.</p>
        </div>
      </div>

      <form className="search-form" onSubmit={submit} role="search">
        <input className="input" value={input} onChange={(e) => setInput(e.target.value)}
               placeholder="e.g. trello clone, habit tracker, realtime chat" aria-label="Project idea" />
        <button className="btn btn-primary" type="submit">Research</button>
      </form>

      {!q && (
        <div className="section">
          <p className="muted">Not sure where to start? Try one of these:</p>
          <div className="chips">
            {EXAMPLES.map((e) => <button key={e} className="chip" onClick={() => setParams({ q: e })}>{e}</button>)}
          </div>
        </div>
      )}

      {loading && <Loading label={`Searching for “${q}”…`} />}
      {error && <ErrorNote message={error} />}

      {results && !loading && (
        <>
          <p className="muted section">{total} results for “{results.query}”</p>
          {results.sections.map((section) => (
            <section className="section" key={section.key}>
              <h2 className="section-title">{section.title}</h2>
              <p className="muted small section-sub">{section.description}</p>
              {section.error ? (
                <p className="note">Couldn&apos;t reach {section.source} just now. Try again in a moment.</p>
              ) : section.items.length === 0 ? (
                <Empty title={`No ${section.source} results`}>Try a broader phrase.</Empty>
              ) : (
                <div className="grid">{section.items.map((item) => <ArticleCard key={item.id + item.url} item={item} />)}</div>
              )}
            </section>
          ))}
        </>
      )}
    </>
  );
}
