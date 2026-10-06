import { useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../api";
import AuthShell from "../components/AuthShell";

export default function ForgotPassword() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      await api.post("/auth/forgot_password", { email });
      setSent(true);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <AuthShell footer={<Link to="/login">Back to sign in</Link>}>
      <form className="card form" onSubmit={submit}>
        <h2 className="card-title">Reset your password</h2>
        {sent ? (
          <p role="status">If an account exists for <strong>{email}</strong>, we&apos;ve emailed a link to reset the password. It works for one hour.</p>
        ) : (
          <>
            <p className="muted">Enter your email and we&apos;ll send you a link to choose a new password.</p>
            {error && <div className="alert alert-error" role="alert">{error}</div>}
            <label className="field"><span>Email</span>
              <input className="input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" required />
            </label>
            <button className="btn btn-primary btn-block" type="submit" disabled={busy}>{busy ? "Sending…" : "Send reset link"}</button>
          </>
        )}
      </form>
    </AuthShell>
  );
}
