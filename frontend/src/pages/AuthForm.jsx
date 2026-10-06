import { useEffect, useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { api } from "../api";
import { useAuth } from "../auth";
import AuthShell from "../components/AuthShell";

// One form for both Login and Register so the two pages stay identical.
export default function AuthForm({ mode }) {
  const isRegister = mode === "register";
  const { login, register } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [form, setForm] = useState({ name: "", email: "", password: "", inviteCode: "" });
  const [inviteRequired, setInviteRequired] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [sentTo, setSentTo] = useState("");   // set when the server asks the person to confirm their email first

  // The server says whether registering needs an invite code.
  useEffect(() => {
    if (isRegister) api.get("/auth/options").then((o) => setInviteRequired(o.invite_required)).catch(() => {});
  }, [isRegister]);

  const update = (field) => (e) => setForm({ ...form, [field]: e.target.value });

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      if (isRegister) {
        const result = await register(form.name, form.email, form.password, form.inviteCode);
        if (result?.verify_email) {
          setSentTo(form.email);
          setBusy(false);
          return;
        }
      } else {
        await login(form.email, form.password);
      }
      navigate(location.state?.from || "/", { replace: true });
    } catch (err) {
      setError(err.message);
      setBusy(false);
    }
  };

  if (sentTo) {
    return (
      <AuthShell footer={<Link to="/login">Back to sign in</Link>}>
        <div className="card form">
          <h2 className="card-title">Check your email</h2>
          <p role="status">
            We&apos;ve sent a message to <strong>{sentTo}</strong>. Open the link in it to finish creating your account,
            then sign in. If you already had an account, the message says so.
          </p>
        </div>
      </AuthShell>
    );
  }

  return (
    <AuthShell
      footer={isRegister ? <>Already have an account? <Link to="/login">Sign in</Link></> : <>New here? <Link to="/register">Create an account</Link></>}
    >
      <form className="card form" onSubmit={submit}>
        <h2 className="card-title">{isRegister ? "Create your account" : "Sign in"}</h2>
        {error && <div className="alert alert-error" role="alert">{error}</div>}

        {isRegister && (
          <label className="field"><span>Name</span>
            <input className="input" value={form.name} onChange={update("name")} autoComplete="name" required maxLength={80} />
          </label>
        )}
        <label className="field"><span>Email</span>
          <input className="input" type="email" value={form.email} onChange={update("email")} autoComplete="email" required />
        </label>
        <label className="field"><span>Password</span>
          <input className="input" type="password" value={form.password} onChange={update("password")}
                 autoComplete={isRegister ? "new-password" : "current-password"} required minLength={isRegister ? 8 : undefined} />
          {isRegister && <small className="muted">At least 8 characters.</small>}
        </label>
        {isRegister && inviteRequired && (
          <label className="field"><span>Invite code</span>
            <input className="input" value={form.inviteCode} onChange={update("inviteCode")} required autoComplete="off" />
          </label>
        )}

        <button className="btn btn-primary btn-block" type="submit" disabled={busy}>
          {busy ? "Please wait…" : isRegister ? "Create account" : "Sign in"}
        </button>
        {!isRegister && <Link className="small" to="/forgot-password">Forgot your password?</Link>}
      </form>
    </AuthShell>
  );
}
