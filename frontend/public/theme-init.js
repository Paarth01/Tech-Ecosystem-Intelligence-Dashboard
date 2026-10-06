// Applies the saved (or system) theme before first paint to avoid a flash.
// It is a separate file so the page's Content-Security-Policy can forbid inline scripts.
(function () {
  var t = localStorage.getItem("theme");
  if (t !== "light" && t !== "dark") t = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  document.documentElement.setAttribute("data-theme", t);
})();
