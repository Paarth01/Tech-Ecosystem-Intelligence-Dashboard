import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import App from "./App";
import { AuthProvider } from "./auth";
import { clearDashboardCache } from "./dashboardStore";
import { LibraryProvider } from "./library";

// A small in-memory stand-in for the Rails API. It follows the same contract (cookie session,
// per-user data, status codes), so these tests walk through the real screens end to end.
function createFakeApi() {
  const users = [];
  const saved = {};
  const comparisons = {};
  let signedInAs = null;      // plays the part of the login cookie
  let nextId = 1;

  const item = (n) => ({ id: String(n), title: `acme/tool-${n}`, url: `https://github.com/acme/tool-${n}`, source: "GitHub",
    description: `Tool number ${n}`, meta: "+100 stars this week", tags: ["Rust"], ecosystems: ["Systems"], topics: ["rust"] });
  const dashboard = {
    feeds: { github: [item(1), item(2)], hackernews: [], devto: [], lobsters: [], stackoverflow: [] },
    topics: [{ name: "Rust", tag: "rust", score: 4.1, source_count: 2, mention_count: 2, ecosystems: ["Systems"],
               mentions: [{ title: "acme/tool-1", url: "https://github.com/acme/tool-1", source: "GitHub" }], trend: { label: "up", percent: 24 } }],
    unavailable: ["hackernews", "devto", "lobsters", "stackoverflow"], ecosystems: ["All", "Systems"], updated_at: new Date().toISOString(),
  };

  const publicUser = (u) => ({ id: u.id, name: u.name, email: u.email, email_verified: false });
  const me = () => users.find((u) => u.id === signedInAs);

  function handle(method, path, body) {
    let m;
    if (method === "GET" && path === "/auth/options") return [200, { invite_required: false }];
    if (method === "POST" && path === "/auth/register") {
      const user = { id: nextId++, ...body };
      users.push(user); saved[user.id] = []; comparisons[user.id] = []; signedInAs = user.id;
      return [201, { user: publicUser(user) }];
    }
    if (method === "POST" && path === "/auth/login") {
      const user = users.find((u) => u.email === body.email && u.password === body.password);
      if (!user) return [401, { error: "Invalid email or password" }];
      signedInAs = user.id;
      return [200, { user: publicUser(user) }];
    }
    if (method === "DELETE" && path === "/auth/logout") { signedInAs = null; return [204]; }
    if (!me()) return [401, { error: "Please sign in" }];

    const uid = signedInAs;
    if (method === "GET" && path === "/me") {
      return [200, { user: publicUser(me()), member_since: new Date().toISOString(), saved_count: saved[uid].length, comparison_count: comparisons[uid].length }];
    }
    if (method === "POST" && path === "/me/verification") return [200, { ok: true }];
    if (method === "DELETE" && path === "/me") {
      if (body.current_password !== me().password) return [422, { error: "Current password is incorrect" }];
      users.splice(users.indexOf(me()), 1); delete saved[uid]; delete comparisons[uid]; signedInAs = null;
      return [204];
    }
    if (method === "GET" && path === "/dashboard") return [200, dashboard];
    if (method === "GET" && path === "/saved_articles") return [200, saved[uid]];
    if (method === "POST" && path === "/saved_articles") {
      const created = { id: nextId++, ...body.article };
      saved[uid].unshift(created);
      return [201, created];
    }
    if ((m = path.match(/^\/saved_articles\/(\d+)$/)) && method === "DELETE") {
      saved[uid] = saved[uid].filter((a) => a.id !== Number(m[1]));
      return [204];
    }
    if (method === "POST" && path === "/comparisons/generate") {
      return [200, { markdown: "| Aspect | A | B |\n|---|---|---|\n| What it is | fast | friendly |", ai: false, note: "Basic comparison." }];
    }
    if (method === "POST" && path === "/comparisons") {
      const created = { id: nextId++, title: body.items.map((i) => i.title).join(" vs "), ai_generated: false, created_at: new Date().toISOString(),
        item_count: body.items.length, sources: ["GitHub"], items: body.items, result: body.result };
      comparisons[uid].unshift(created);
      return [201, created];
    }
    if (method === "GET" && path === "/comparisons") return [200, comparisons[uid]];
    if ((m = path.match(/^\/comparisons\/(\d+)$/))) {
      const found = comparisons[uid].find((c) => c.id === Number(m[1]));
      if (!found) return [404, { error: "Not found" }];
      if (method === "GET") return [200, found];
      comparisons[uid] = comparisons[uid].filter((c) => c !== found);
      return [204];
    }
    return [404, { error: "Not found" }];
  }

  return {
    users,
    fetch: (url, options = {}) => {
      const [status, data] = handle(options.method || "GET", url.replace(/^\/api/, ""), options.body ? JSON.parse(options.body) : {});
      return Promise.resolve({ status, ok: status < 400, json: () => Promise.resolve(data ?? {}) });
    },
  };
}

const renderApp = (path) => render(
  <MemoryRouter initialEntries={[path]}><AuthProvider><LibraryProvider><App /></LibraryProvider></AuthProvider></MemoryRouter>
);
const heading = (name) => screen.findByRole("heading", { name });
const type = (label, value) => fireEvent.change(screen.getByLabelText(label), { target: { value } });
const click = (name) => fireEvent.click(screen.getByRole("button", { name }));
const navLink = (name) => fireEvent.click(screen.getByRole("link", { name }));

async function register(name, email) {
  await heading("Create your account");
  type("Name", name); type("Email", email); type(/^Password/, "password123");
  click("Create account");
  await heading("Today in tech");
}

beforeEach(() => {
  vi.stubGlobal("fetch", createFakeApi().fetch);
  vi.spyOn(window, "confirm").mockReturnValue(true);
  sessionStorage.clear();
  clearDashboardCache();
});
afterEach(() => { vi.unstubAllGlobals(); vi.restoreAllMocks(); });

describe("a user's journey through the app", () => {
  it("registers, saves, compares, keeps a comparison, and deletes it", async () => {
    renderApp("/register");
    await register("Ada", "ada@example.com");

    expect(screen.getAllByText("↑ 24%").length).toBeGreaterThan(0);          // trend badge from the dashboard

    // Save the first article
    const cards = screen.getAllByRole("article");
    fireEvent.click(within(cards[0]).getByRole("button", { name: "Save" }));
    await waitFor(() => expect(within(screen.getAllByRole("article")[0]).getByRole("button", { name: "Saved" })).toBeTruthy());

    // Pick both for comparison, then compare from the tray
    fireEvent.click(within(screen.getAllByRole("article")[0]).getByRole("button", { name: "Compare" }));
    fireEvent.click(within(screen.getAllByRole("article")[1]).getByRole("button", { name: "Compare" }));
    click("Compare");
    await heading("Compare articles");
    click("Generate comparison");
    expect(await screen.findByRole("table")).toBeTruthy();
    expect(screen.getByText("Basic comparison.")).toBeTruthy();
    click("Save comparison");
    expect(await screen.findByRole("link", { name: "View it" })).toBeTruthy();

    // It shows up in the saved comparisons list, and can be deleted
    navLink("Comparisons");
    await heading("Saved comparisons");
    expect(await screen.findByText("acme/tool-1 vs acme/tool-2")).toBeTruthy();
    click("Delete");
    expect(await screen.findByText("No saved comparisons")).toBeTruthy();

    // The saved article is on the Saved page
    navLink(/^Saved/);
    await heading("Saved articles");
    const savedCards = await screen.findAllByRole("article");
    expect(savedCards).toHaveLength(1);                                   // only the one article that was saved
    expect(within(savedCards[0]).getByText("acme/tool-1")).toBeTruthy();
  });

  it("a second user never sees the first user's saved articles", async () => {
    renderApp("/register");
    await register("Ada", "ada@example.com");
    fireEvent.click(within(screen.getAllByRole("article")[0]).getByRole("button", { name: "Save" }));
    await waitFor(() => expect(screen.getAllByRole("button", { name: "Saved" })).toHaveLength(1));

    click("Sign out");
    await heading("Sign in");

    fireEvent.click(screen.getByRole("link", { name: "Create an account" }));
    await register("Bob", "bob@example.com");
    navLink(/^Saved/);
    await heading("Saved articles");
    expect(await screen.findByText("Nothing saved yet")).toBeTruthy();
    expect(screen.queryByText("acme/tool-1")).toBeNull();
  });

  it("protects the app after signing out", async () => {
    renderApp("/register");
    await register("Ada", "ada@example.com");
    click("Sign out");
    await heading("Sign in");
    expect(screen.queryByRole("heading", { name: "Today in tech" })).toBeNull();
  });

  it("asks to confirm the email, can resend the link, and can delete the account with the password", async () => {
    const api = createFakeApi();
    vi.stubGlobal("fetch", api.fetch);
    renderApp("/register");
    await register("Ada", "ada@example.com");

    fireEvent.click(screen.getByRole("link", { name: "Ada" }));
    await heading("Account");
    expect(screen.getByText(/Please confirm your email address/)).toBeTruthy();
    click("Resend email");
    expect(await screen.findByText("Email sent. Check your inbox.")).toBeTruthy();

    type("Confirm with your password", "wrong-password");
    click("Delete my account");
    expect(await screen.findByText("Current password is incorrect")).toBeTruthy();
    expect(api.users).toHaveLength(1);

    type("Confirm with your password", "password123");
    click("Delete my account");
    await heading("Sign in");
    expect(api.users).toHaveLength(0);
  });
});
