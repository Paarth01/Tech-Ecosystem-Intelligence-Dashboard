import { useEffect, useRef, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { api } from "../api";
import { useAuth } from "../auth";
import AuthShell from "../components/AuthShell";

// Opened from the link in the verification email, whether or not the visitor is signed in.
export default function VerifyEmail() {
  const [params] = useSearchParams();
  const token = params.get("token");
  const { user, setUser } = useAuth();
  const [state, setState] = useState(token ? "working" : "invalid");
  const [message, setMessage] = useState("");
  const started = useRef(false);   // the link works once, so make sure it is only used once

  useEffect(() => {
    if (!token || started.current) return;
    started.current = true;
    api.post("/auth/verify_email", { token })
      .then(() => {
        setState("done");
        setUser((current) => (current ? { ...current, email_verified: true } : current));
      })
      .catch((e) => { setState("invalid"); setMessage(e.message); });
  }, [token, setUser]);

  return (
    <AuthShell>
      <div className="card form" role="status">
        <h2 className="card-title">Email confirmation</h2>
        {state === "working" && <p>Confirming your email…</p>}
        {state === "done" && <p>Thanks, your email address is confirmed. <Link to={user ? "/" : "/login"}>{user ? "Go to the dashboard" : "Sign in"}</Link></p>}
        {state === "invalid" && (
          <p>{message || "This confirmation link is incomplete."} {user ? <>You can ask for a new one on your <Link to="/account">account page</Link>.</> : <>Sign in and ask for a new one on your account page.</>}</p>
        )}
      </div>
    </AuthShell>
  );
}
