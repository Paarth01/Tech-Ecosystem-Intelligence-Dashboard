import { afterEach, describe, expect, it, vi } from "vitest";
import { api, setUnauthorizedHandler } from "./api";

const reply = (status, body) => Promise.resolve({ status, ok: status < 400, json: () => Promise.resolve(body) });

afterEach(() => vi.unstubAllGlobals());

describe("api client", () => {
  it("sends the CSRF header, JSON body and same-origin cookies, and never an Authorization header", async () => {
    const fetchMock = vi.fn(() => reply(200, { ok: true }));
    vi.stubGlobal("fetch", fetchMock);
    await api.post("/saved_articles", { article: { title: "x" } });

    const [url, options] = fetchMock.mock.calls[0];
    expect(url).toBe("/api/saved_articles");
    expect(options.method).toBe("POST");
    expect(options.credentials).toBe("same-origin");
    expect(options.headers["X-Requested-With"]).toBe("XMLHttpRequest");
    expect(options.headers["Content-Type"]).toBe("application/json");
    expect(options.headers.Authorization).toBeUndefined();
    expect(JSON.parse(options.body)).toEqual({ article: { title: "x" } });
  });

  it("signs the user out when a normal request returns 401, but not for a failed login", async () => {
    const handler = vi.fn();
    setUnauthorizedHandler(handler);

    vi.stubGlobal("fetch", vi.fn(() => reply(401, { error: "Please sign in" })));
    await expect(api.get("/saved_articles")).rejects.toThrow("Please sign in");
    expect(handler).toHaveBeenCalledTimes(1);

    vi.stubGlobal("fetch", vi.fn(() => reply(401, { error: "Invalid email or password" })));
    await expect(api.post("/auth/login", {})).rejects.toThrow("Invalid email or password");
    expect(handler).toHaveBeenCalledTimes(1);
  });

  it("shows the server's message, including rate limits, and handles an unreachable server", async () => {
    vi.stubGlobal("fetch", vi.fn(() => reply(429, { error: "You're doing that too often. Try again in 3 minute(s)." })));
    await expect(api.get("/search?q=x")).rejects.toThrow("too often");

    vi.stubGlobal("fetch", vi.fn(() => reply(500, {})));
    await expect(api.get("/dashboard")).rejects.toThrow("isn't responding");

    vi.stubGlobal("fetch", vi.fn(() => Promise.reject(new TypeError("Failed to fetch"))));
    await expect(api.get("/dashboard")).rejects.toThrow("Can't reach the server");
  });

  it("sends a JSON body with DELETE (used to confirm account deletion)", async () => {
    const fetchMock = vi.fn(() => Promise.resolve({ status: 204, ok: true }));
    vi.stubGlobal("fetch", fetchMock);
    await api.del("/me", { current_password: "secret" });
    expect(fetchMock.mock.calls[0][1].method).toBe("DELETE");
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({ current_password: "secret" });
  });

  it("returns null for 204 responses", async () => {
    vi.stubGlobal("fetch", vi.fn(() => Promise.resolve({ status: 204, ok: true })));
    expect(await api.del("/saved_articles/1")).toBeNull();
  });
});
