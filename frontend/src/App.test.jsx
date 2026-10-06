import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";

const auth = { user: null, loading: false, login: vi.fn(), register: vi.fn(), logout: vi.fn(), setUser: vi.fn() };
vi.mock("./auth", () => ({ useAuth: () => auth, AuthProvider: ({ children }) => children }));

import App from "./App";

const visit = (path) => render(<MemoryRouter initialEntries={[path]}><App /></MemoryRouter>);

describe("route protection", () => {
  it.each(["/", "/saved", "/comparisons", "/comparisons/5", "/compare", "/account", "/research?q=rails"])(
    "sends a signed-out visitor from %s to the sign-in page",
    (path) => {
      visit(path);
      expect(screen.getByRole("heading", { name: "Sign in" })).toBeTruthy();
    }
  );

  it("lets a signed-out visitor open the register page", () => {
    visit("/register");
    expect(screen.getByRole("heading", { name: "Create your account" })).toBeTruthy();
  });

  it("after an email-first sign-up it asks the person to check their email instead of signing them in", async () => {
    auth.register.mockResolvedValueOnce({ ok: true, verify_email: true });
    visit("/register");
    fireEvent.change(screen.getByLabelText("Name"), { target: { value: "Ada" } });
    fireEvent.change(screen.getByLabelText("Email"), { target: { value: "ada@example.com" } });
    fireEvent.change(screen.getByLabelText(/^Password/), { target: { value: "password123" } });
    fireEvent.click(screen.getByRole("button", { name: "Create account" }));
    expect(await screen.findByRole("heading", { name: "Check your email" })).toBeTruthy();
    expect(screen.getByText("ada@example.com")).toBeTruthy();
  });

  it("shows a loading state, not protected content, while the session is being checked", () => {
    auth.loading = true;
    visit("/saved");
    auth.loading = false;
    expect(screen.getByText("Loading…")).toBeTruthy();
    expect(screen.queryByRole("heading", { name: "Saved articles" })).toBeNull();
  });
});

const reply = (status, body) => Promise.resolve({ status, ok: status < 400, json: () => Promise.resolve(body) });
const field = (label) => screen.getByLabelText(label);

describe("password and email pages", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("forgot password asks for an email and shows the same confirmation either way", async () => {
    const fetchMock = vi.fn(() => reply(200, { ok: true }));
    vi.stubGlobal("fetch", fetchMock);
    visit("/forgot-password");
    fireEvent.change(field("Email"), { target: { value: "ada@example.com" } });
    fireEvent.click(screen.getByRole("button", { name: "Send reset link" }));

    expect(await screen.findByText(/we've emailed a link/)).toBeTruthy();
    expect(fetchMock.mock.calls[0][0]).toBe("/api/auth/forgot_password");
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({ email: "ada@example.com" });
  });

  it("reset password sends the token from the link and the new password", async () => {
    const fetchMock = vi.fn(() => reply(200, { ok: true }));
    vi.stubGlobal("fetch", fetchMock);
    visit("/reset-password?token=abc123");
    fireEvent.change(field(/^New password/), { target: { value: "newpassword1" } });
    fireEvent.click(screen.getByRole("button", { name: "Change password" }));

    expect(await screen.findByText(/signed out everywhere/)).toBeTruthy();
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({ token: "abc123", password: "newpassword1" });
  });

  it("reset password shows the server's message for an expired link, and handles a missing token", async () => {
    vi.stubGlobal("fetch", vi.fn(() => reply(422, { error: "This reset link is invalid or has expired." })));
    visit("/reset-password?token=old");
    fireEvent.change(field(/^New password/), { target: { value: "newpassword1" } });
    fireEvent.click(screen.getByRole("button", { name: "Change password" }));
    expect(await screen.findByText(/invalid or has expired/)).toBeTruthy();
  });

  it("reset password without a token explains the link is incomplete", () => {
    visit("/reset-password");
    expect(screen.getByText(/incomplete/)).toBeTruthy();
  });

  it("confirms an email address from the link, once", async () => {
    const fetchMock = vi.fn(() => reply(200, { ok: true }));
    vi.stubGlobal("fetch", fetchMock);
    visit("/verify-email?token=tok1");
    expect(await screen.findByText(/email address is confirmed/)).toBeTruthy();
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock.mock.calls[0][0]).toBe("/api/auth/verify_email");
  });

  it("reports an invalid confirmation link", async () => {
    vi.stubGlobal("fetch", vi.fn(() => reply(422, { error: "This verification link is invalid or has expired." })));
    visit("/verify-email?token=bad");
    await waitFor(() => expect(screen.getByText(/invalid or has expired/)).toBeTruthy());
  });

  it("the sign-in page links to password reset", () => {
    visit("/login");
    expect(screen.getByRole("link", { name: "Forgot your password?" })).toBeTruthy();
  });
});
