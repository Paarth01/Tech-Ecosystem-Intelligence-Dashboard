import { ThemeToggle } from "../theme";

// The centred card layout shared by sign in, register, and the password / email pages.
export default function AuthShell({ children, footer }) {
  return (
    <div className="auth-page">
      <div className="auth-theme"><ThemeToggle /></div>
      <div className="auth-box">
        <h1 className="auth-brand">Tech Ecosystem Intelligence</h1>
        <p className="muted auth-sub">See which frameworks, languages and tools are gaining real traction, and keep your own reading list.</p>
        {children}
        {footer && <p className="muted auth-switch">{footer}</p>}
      </div>
    </div>
  );
}
