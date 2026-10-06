// Small fetch wrapper. The login lives in an HttpOnly cookie that the browser sends by itself,
// so no token is ever handled (or stolen) by JavaScript. The X-Requested-With header is what
// the server checks on every write to block forged cross-site requests.
let onUnauthorized = () => {};
export const setUnauthorizedHandler = (fn) => { onUnauthorized = fn; };

async function request(method, path, body) {
  const headers = { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" };
  if (body !== undefined) headers["Content-Type"] = "application/json";

  let res;
  try {
    res = await fetch(`/api${path}`, {
      method,
      headers,
      credentials: "same-origin",
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new Error("Can't reach the server. Check your connection and try again.");
  }

  if (res.status === 204) return null;
  const data = await res.json().catch(() => ({}));

  if (!res.ok) {
    // A 401 outside the login/register calls means the session ended: go back to sign in.
    if (res.status === 401 && !path.startsWith("/auth/")) onUnauthorized();
    if (!data.error && res.status >= 500) {
      throw new Error("The server isn't responding. Make sure the Rails API is running.");
    }
    throw new Error(data.error || `Request failed (${res.status})`);
  }
  return data;
}

export const api = {
  get: (path) => request("GET", path),
  post: (path, body = {}) => request("POST", path, body),
  patch: (path, body) => request("PATCH", path, body),
  del: (path, body) => request("DELETE", path, body),
};
