import { useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { api } from "../api";
import AuthShell from "../components/AuthShell";

export default function ResetPassword() {
  const [params] = useSearchParams();
  const token = params.get("token");
  const [password, setPassword] = useState("");
  const [done, setDone] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      await api.post("/auth/reset_password", { token, password });
      setDone(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <AuthShell footer={<Link to="/login">Back to sign in</Link>}>
      <form className="card form" onSubmit={submit}>
        <h2 className="card-title">Choose a new password</h2>
        {done ? (
          <p role="status">Your password was changed and you were signed out everywhere. <Link to="/login">Sign in with your new password</Link>.</p>
        ) : !token ? (
          <p>This reset link is incomplete. <Link to="/forgot-password">Request a new one</Link>.</p>
        ) : (
          <>
            {error && <div className="alert alert-error" role="alert">{error} <Link to="/forgot-password">Request a new link</Link></div>}
            <label className="field"><span>New password</span>
              <input className="input" type="password" value={password} onChange={(e) => setPassword(e.target.value)}
                     autoComplete="new-password" minLength={8} required />
              <small className="muted">At least 8 characters.</small>
            </label>
            <button className="btn btn-primary btn-block" type="submit" disabled={busy}>{busy ? "Saving…" : "Change password"}</button>
          </>
        )}
      </form>
    </AuthShell>
  );
}
