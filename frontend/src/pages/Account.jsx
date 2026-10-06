import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../api";
import { useAuth } from "../auth";
import { ErrorNote, Loading } from "../components/PageState";
import { formatDate } from "../format";

export default function Account() {
  const { user, setUser, logout, endSession } = useAuth();
  const navigate = useNavigate();
  const [info, setInfo] = useState(null);
  const [name, setName] = useState(user.name);
  const [pw, setPw] = useState({ current: "", next: "" });
  const [deletePassword, setDeletePassword] = useState("");
  const [profileMsg, setProfileMsg] = useState("");
  const [pwMsg, setPwMsg] = useState("");
  const [verifyMsg, setVerifyMsg] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    api.get("/me").then((data) => { setInfo(data); setUser(data.user); }).catch((e) => setError(e.message));
  }, [setUser]);

  const saveProfile = async (e) => {
    e.preventDefault();
    setProfileMsg("");
    setError("");
    try {
      const data = await api.patch("/me", { name });
      setUser(data.user);
      setProfileMsg("Profile updated.");
    } catch (err) {
      setError(err.message);
    }
  };

  const changePassword = async (e) => {
    e.preventDefault();
    setPwMsg("");
    setError("");
    try {
      await api.patch("/me", { current_password: pw.current, password: pw.next });
      setPw({ current: "", next: "" });
      setPwMsg("Password changed. Other devices were signed out.");
    } catch (err) {
      setError(err.message);
    }
  };

  const resendVerification = async () => {
    setVerifyMsg("");
    setError("");
    try {
      await api.post("/me/verification");
      setVerifyMsg("Email sent. Check your inbox.");
    } catch (err) {
      setError(err.message);
    }
  };

  const deleteAccount = async (e) => {
    e.preventDefault();
    if (!window.confirm("This permanently deletes your account, saved articles and comparisons. Continue?")) return;
    setError("");
    try {
      await api.del("/me", { current_password: deletePassword });
      endSession();
      navigate("/login");
    } catch (err) {
      setError(err.message);
    }
  };

  const signOut = async () => { await logout(); navigate("/login"); };

  if (!info && !error) return <Loading />;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Account</h1>
          <p className="muted">{user.email}{info ? ` · member since ${formatDate(info.member_since)}` : ""}</p>
        </div>
        <button className="btn btn-secondary btn-sm" onClick={signOut}>Sign out</button>
      </div>

      {error && <ErrorNote message={error} />}

      {!user.email_verified && (
        <div className="banner" role="status">
          <span>Please confirm your email address. We sent a link to {user.email}.</span>
          <span className="banner-actions">
            {verifyMsg && <span className="small">{verifyMsg}</span>}
            <button className="btn btn-secondary btn-sm" onClick={resendVerification}>Resend email</button>
          </span>
        </div>
      )}

      {info && (
        <div className="stats">
          <div className="card stat"><span className="stat-n">{info.saved_count}</span><span className="muted">Saved articles</span></div>
          <div className="card stat"><span className="stat-n">{info.comparison_count}</span><span className="muted">Saved comparisons</span></div>
        </div>
      )}

      <div className="two-col">
        <form className="card form" onSubmit={saveProfile}>
          <h2 className="card-title">Profile</h2>
          <label className="field"><span>Name</span>
            <input className="input" value={name} onChange={(e) => setName(e.target.value)} required maxLength={80} />
          </label>
          <label className="field"><span>Email</span>
            <input className="input" value={user.email} disabled />
          </label>
          <div className="form-actions">
            <button className="btn btn-primary" type="submit">Save changes</button>
            {profileMsg && <span className="muted small" role="status">{profileMsg}</span>}
          </div>
        </form>

        <form className="card form" onSubmit={changePassword}>
          <h2 className="card-title">Change password</h2>
          <label className="field"><span>Current password</span>
            <input className="input" type="password" autoComplete="current-password" value={pw.current}
                   onChange={(e) => setPw({ ...pw, current: e.target.value })} required />
          </label>
          <label className="field"><span>New password</span>
            <input className="input" type="password" autoComplete="new-password" minLength={8} value={pw.next}
                   onChange={(e) => setPw({ ...pw, next: e.target.value })} required />
            <small className="muted">At least 8 characters.</small>
          </label>
          <div className="form-actions">
            <button className="btn btn-primary" type="submit">Update password</button>
            {pwMsg && <span className="muted small" role="status">{pwMsg}</span>}
          </div>
        </form>
      </div>

      <form className="card form danger-zone" onSubmit={deleteAccount}>
        <h2 className="card-title">Delete account</h2>
        <p className="muted">This permanently removes your account, saved articles and comparisons. It can't be undone.</p>
        <label className="field"><span>Confirm with your password</span>
          <input className="input" type="password" autoComplete="current-password" value={deletePassword}
                 onChange={(e) => setDeletePassword(e.target.value)} required />
        </label>
        <div className="form-actions">
          <button className="btn btn-danger" type="submit">Delete my account</button>
        </div>
      </form>
    </>
  );
}
