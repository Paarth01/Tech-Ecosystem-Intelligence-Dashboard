import { act, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

const session = { user: { id: 1 } };
vi.mock("./auth", () => ({ useAuth: () => session }));
vi.mock("./api", () => ({ api: { get: vi.fn(), post: vi.fn(), del: vi.fn() } }));

import { api } from "./api";
import { LibraryProvider, useLibrary } from "./library";

let library;
function Probe() {
  library = useLibrary();
  return <p data-testid="titles">{library.saved.map((a) => a.title).join(",")}</p>;
}
const ui = () => <LibraryProvider><Probe /></LibraryProvider>;
const deferred = () => { let resolve; const promise = new Promise((r) => { resolve = r; }); return { promise, resolve }; };
const titles = () => screen.getByTestId("titles").textContent;

beforeEach(() => { vi.resetAllMocks(); sessionStorage.clear(); session.user = { id: 1 }; });

describe("saved articles belong to the signed-in user", () => {
  it("ignores a slow response for the previous user after the account changes", async () => {
    const forAlice = deferred();
    const forBob = deferred();
    api.get.mockReturnValueOnce(forAlice.promise).mockReturnValueOnce(forBob.promise);

    const view = render(ui());                              // Alice signs in; her list is still loading
    session.user = { id: 2 };
    view.rerender(ui());                                    // Bob signs in

    await act(async () => { forBob.resolve([{ id: 20, url: "https://b", title: "Bob's article" }]); });
    await waitFor(() => expect(titles()).toBe("Bob's article"));

    await act(async () => { forAlice.resolve([{ id: 10, url: "https://a", title: "Alice's article" }]); });
    expect(titles()).toBe("Bob's article");                 // Alice's late response is discarded
  });

  it("clears the list as soon as the user signs out", async () => {
    api.get.mockResolvedValue([{ id: 1, url: "https://a", title: "Mine" }]);
    const view = render(ui());
    await waitFor(() => expect(titles()).toBe("Mine"));

    session.user = null;
    view.rerender(ui());
    expect(titles()).toBe("");
  });

  it("does not add an article to the next user's list if the save finishes after a user change", async () => {
    api.get.mockResolvedValue([]);
    const slowSave = deferred();
    api.post.mockReturnValue(slowSave.promise);

    const view = render(ui());
    await waitFor(() => expect(api.get).toHaveBeenCalled());
    let saving;
    act(() => { saving = library.toggleSave({ title: "Alice's save", url: "https://a" }); });

    session.user = { id: 2 };
    view.rerender(ui());
    await act(async () => { slowSave.resolve({ id: 5, url: "https://a", title: "Alice's save" }); await saving; });

    expect(titles()).toBe("");
  });

  it("keeps each user's compare selection separate", async () => {
    api.get.mockResolvedValue([]);
    const view = render(ui());
    await waitFor(() => expect(api.get).toHaveBeenCalled());
    act(() => library.toggleSelected({ title: "A", url: "https://a" }));
    expect(library.selected).toHaveLength(1);

    session.user = { id: 2 };
    view.rerender(ui());
    await waitFor(() => expect(library.selected).toHaveLength(0));
  });
});
