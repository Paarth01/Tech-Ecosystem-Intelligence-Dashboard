import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("./api", () => ({ api: { get: vi.fn(), post: vi.fn() } }));
import { api } from "./api";
import { MAX_AGE_MS, clearDashboardCache, loadDashboard } from "./dashboardStore";

describe("dashboard store", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-01-01T00:00:00Z"));
    api.get.mockReset().mockResolvedValue({ feeds: {} });
    api.post.mockReset().mockResolvedValue({ feeds: {}, refreshed: true });
    clearDashboardCache();
  });
  afterEach(() => vi.useRealTimers());

  it("reuses the loaded dashboard for a few minutes", async () => {
    await loadDashboard();
    await loadDashboard();
    expect(api.get).toHaveBeenCalledTimes(1);
  });

  it("fetches again once the data is older than the limit, so an open tab can't go stale", async () => {
    await loadDashboard();
    vi.setSystemTime(Date.now() + MAX_AGE_MS + 1000);
    await loadDashboard();
    expect(api.get).toHaveBeenCalledTimes(2);
  });

  it("refreshing is a POST, never a GET link", async () => {
    await loadDashboard();
    const data = await loadDashboard(true);
    expect(api.post).toHaveBeenCalledWith("/dashboard/refresh");
    expect(data.refreshed).toBe(true);
    expect(api.get).toHaveBeenCalledTimes(1);
  });

  it("a failed load is not remembered", async () => {
    api.get.mockRejectedValueOnce(new Error("down"));
    await expect(loadDashboard()).rejects.toThrow("down");
    await loadDashboard();
    expect(api.get).toHaveBeenCalledTimes(2);
  });
});
