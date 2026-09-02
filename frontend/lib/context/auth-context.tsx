"use client";

import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from "react";
import type { User, LoginRequest, RegisterRequest } from "@/lib/types";
import * as authApi from "@/lib/api/auth";

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (data: LoginRequest) => Promise<void>;
  register: (data: RegisterRequest) => Promise<void>;
  logout: () => Promise<void>;
  updateUser: (data: Partial<User>) => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const token = typeof window !== "undefined" ? localStorage.getItem("finance_tracker_token") : null;
    if (token) {
      authApi.getProfile()
        .then((res) => { if (res.success) setUser(res.data); })
        .catch(() => { localStorage.removeItem("finance_tracker_token"); })
        .finally(() => setIsLoading(false));
    } else {
      setIsLoading(false);
    }
  }, []);

  const login = useCallback(async (data: LoginRequest) => {
    const res = await authApi.login(data);
    if (res.success) setUser(res.data.user);
    else throw new Error(res.message || "Login failed");
  }, []);

  const register = useCallback(async (data: RegisterRequest) => {
    const res = await authApi.register(data);
    if (res.success) setUser(res.data.user);
    else throw new Error(res.message || "Registration failed");
  }, []);

  const logout = useCallback(async () => {
    await authApi.logout();
    setUser(null);
  }, []);

  const updateUser = useCallback((data: Partial<User>) => {
    setUser((prev) => (prev ? { ...prev, ...data } : null));
  }, []);

  return (
    <AuthContext.Provider value={{ user, isAuthenticated: !!user, isLoading, login, register, logout, updateUser }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used within an AuthProvider");
  return context;
}
