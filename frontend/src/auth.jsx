import { createContext, useCallback, useContext, useEffect, useState } from "react";
import { api, setUnauthorizedHandler } from "./api";
import { clearDashboardCache } from "./dashboardStore";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  const clearSession = useCallback(() => {
    clearDashboardCache();
    setUser(null);
  }, []);

  useEffect(() => { setUnauthorizedHandler(clearSession); }, [clearSession]);

  // On page load, ask the server who is signed in (the browser sends the login cookie itself).
  useEffect(() => {
    let cancelled = false;
    api.get("/me")
      .then((data) => !cancelled && setUser(data.user))
      .catch(() => {})
      .finally(() => !cancelled && setLoading(false));
    return () => { cancelled = true; };
  }, []);

  const value = {
    user,
    loading,
    login: async (email, password) => setUser((await api.post("/auth/login", { email, password })).user),
    // Signs in right away, unless the server runs email-first sign-up: then it only says "check your email".
    register: async (name, email, password, inviteCode) => {
      const data = await api.post("/auth/register", { name, email, password, invite_code: inviteCode });
      if (data.user) setUser(data.user);
      return data;
    },
    logout: async () => {
      try { await api.del("/auth/logout"); } catch { /* sign out locally even if the server is down */ }
      clearSession();
    },
    setUser,
    endSession: clearSession,   // after the account is deleted
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export const useAuth = () => useContext(AuthContext);
