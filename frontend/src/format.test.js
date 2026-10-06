import { describe, expect, it } from "vitest";
import { timeAgo } from "./format";

describe("timeAgo", () => {
  const now = new Date("2026-10-04T12:00:00Z").getTime();
  const ago = (ms) => new Date(now - ms).toISOString();

  it("describes recent and older times", () => {
    expect(timeAgo(ago(20_000), now)).toBe("just now");
    expect(timeAgo(ago(60_000), now)).toBe("1 minute ago");
    expect(timeAgo(ago(12 * 60_000), now)).toBe("12 minutes ago");
    expect(timeAgo(ago(3 * 3_600_000), now)).toBe("3 hours ago");
    expect(timeAgo(ago(2 * 86_400_000), now)).toBe("2 days ago");
  });

  it("never returns a negative time", () => {
    expect(timeAgo(new Date(now + 60_000).toISOString(), now)).toBe("just now");
  });
});
