// Small helpers for loading, error and empty states so pages stay short.
export function Loading({ label = "Loading…" }) {
  return <div className="state" role="status">{label}</div>;
}

export function ErrorNote({ message, onRetry }) {
  return (
    <div className="alert alert-error" role="alert">
      <span>{message}</span>
      {onRetry && <button className="btn btn-secondary btn-sm" onClick={onRetry}>Try again</button>}
    </div>
  );
}

export function Empty({ title, children }) {
  return (
    <div className="empty">
      <h3>{title}</h3>
      {children && <p className="muted">{children}</p>}
    </div>
  );
}
