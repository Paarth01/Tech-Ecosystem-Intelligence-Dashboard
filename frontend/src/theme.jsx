import { useState } from "react";

export function ThemeToggle() {
  const [theme, setTheme] = useState(document.documentElement.getAttribute("data-theme") || "light");

  const toggle = () => {
    const next = theme === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    localStorage.setItem("theme", next);
    setTheme(next);
  };

  return (
    <button className="btn btn-ghost btn-sm" onClick={toggle} aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} theme`}>
      {theme === "dark" ? "Light" : "Dark"}
    </button>
  );
}
