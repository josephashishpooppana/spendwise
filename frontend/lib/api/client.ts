// ============================================================
// API Client - Base fetch wrapper for REST API communication
// Toggle USE_MOCK to switch between mock data and real backend
// ============================================================

import type { ApiResponse } from "@/lib/types";

// Set to false and update BASE_URL when connecting to a real backend
// export const USE_MOCK = true;
export const USE_MOCK = false;

// Update this to your backend URL (Python/Flask, PHP/Laravel, Node/Express, etc.)
export const BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000/api/v1";

const CSRF_COOKIE_NAME = "csrftoken";
const CSRF_HEADER_NAME = "X-CSRFToken";

function getAuthToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem("finance_tracker_token");
}

/** Get CSRF token from cookie (browser only). Django sets this when we call GET /auth/csrf/ */
function getCsrfToken(): string | null {
  if (typeof document === "undefined") return null;
  const match = document.cookie.match(
    new RegExp("(^| )" + CSRF_COOKIE_NAME + "=([^;]+)")
  );
  return match ? decodeURIComponent(match[2]) : null;
}

/** Fetch CSRF cookie from backend so we can send it on POST/PUT/DELETE. Call with credentials. */
export async function ensureCsrfCookie(): Promise<void> {
  if (USE_MOCK) return;
  await fetch(`${BASE_URL}/auth/csrf/`, { credentials: "include" });
}

export function setAuthToken(token: string) {
  if (typeof window !== "undefined") {
    localStorage.setItem("finance_tracker_token", token);
  }
}

export function clearAuthToken() {
  if (typeof window !== "undefined") {
    localStorage.removeItem("finance_tracker_token");
  }
}

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
    this.name = "ApiError";
  }
}

export async function apiRequest<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<ApiResponse<T>> {
  const token = getAuthToken();
  const method = (options.method || "GET").toUpperCase();
  const isStateChanging =
    method === "POST" || method === "PUT" || method === "PATCH" || method === "DELETE";

  let csrfToken = getCsrfToken();
  if (isStateChanging && !USE_MOCK && !csrfToken) {
    await ensureCsrfCookie();
    csrfToken = getCsrfToken();
  }

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };

  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }
  if (csrfToken) {
    headers[CSRF_HEADER_NAME] = csrfToken;
  }

  const response = await fetch(`${BASE_URL}${endpoint}`, {
    ...options,
    credentials: "include",
    headers,
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new ApiError(
      errorData.message || `Request failed with status ${response.status}`,
      response.status
    );
  }

  return response.json();
}

export async function apiUpload<T>(
  endpoint: string,
  formData: FormData
): Promise<ApiResponse<T>> {
  const token = getAuthToken();
  let csrfToken = getCsrfToken();
  if (!USE_MOCK && !csrfToken) {
    await ensureCsrfCookie();
    csrfToken = getCsrfToken();
  }

  const headers: Record<string, string> = {};
  if (token) headers["Authorization"] = `Bearer ${token}`;
  if (csrfToken) headers[CSRF_HEADER_NAME] = csrfToken;

  const response = await fetch(`${BASE_URL}${endpoint}`, {
    method: "POST",
    credentials: "include",
    headers,
    body: formData,
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new ApiError(
      errorData.message || `Upload failed with status ${response.status}`,
      response.status
    );
  }

  return response.json();
}

// Utility to simulate network delay in mock mode
export function mockDelay(ms: number = 300): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Utility to create a mock API response
export function mockResponse<T>(data: T, message?: string): ApiResponse<T> {
  return { success: true, data, message };
}

export function mockPaginatedResponse<T>(
  data: T,
  page: number,
  limit: number,
  total: number
): ApiResponse<T> {
  return {
    success: true,
    data,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };
}
