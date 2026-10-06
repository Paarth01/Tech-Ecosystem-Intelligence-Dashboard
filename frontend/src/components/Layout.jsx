import { useEffect, useState } from "react";
import { Link, NavLink, Outlet, useNavigate } from "react-router-dom";
import { useAuth } from "../auth";
import { useLibrary } from "../library";
import { ThemeToggle } from "../theme";
import CommandPalette from "./CommandPalette";
import CompareTray from "./CompareTray";

export default function Layout() {
  const { user, logout } = useAuth();
  const { saved } = useLibrary();
  const navigate = useNavigate();
  const [paletteOpen, setPaletteOpen] = useState(false);

  // Ctrl/Cmd + K toggles the palette from any page. This is the only place it is registered.
  useEffect(() => {
    const onKey = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setPaletteOpen((open) => !open);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const signOut = async () => {
    await logout();
    navigate("/login");
  };

  return (
    <div className="app">
      <header className="nav">
        <div className="container nav-inner">
          <Link to="/" className="brand">Tech Ecosystem</Link>

          <nav className="nav-links" aria-label="Main">
            <NavLink to="/" end>Dashboard</NavLink>
            <NavLink to="/research">Research</NavLink>
            <NavLink to="/saved">Saved{saved.length > 0 && <span className="count">{saved.length}</span>}</NavLink>
            <NavLink to="/comparisons">Comparisons</NavLink>
          </nav>

          <div className="nav-actions">
            <button className="btn btn-secondary btn-sm search-trigger" onClick={() => setPaletteOpen(true)}>
              Search <kbd>Ctrl K</kbd>
            </button>
            <ThemeToggle />
            <NavLink to="/account" className="nav-user">{user.name}</NavLink>
            <button className="btn btn-ghost btn-sm" onClick={signOut}>Sign out</button>
          </div>
        </div>
      </header>

      <main className="container main">
        <Outlet />
      </main>

      <footer className="container footer">
        Data from GitHub, Hacker News, Dev.to, Lobsters, Stack Overflow and Reddit. Refreshed hourly.
      </footer>

      <CompareTray />
      {paletteOpen && <CommandPalette onClose={() => setPaletteOpen(false)} />}
    </div>
  );
}
