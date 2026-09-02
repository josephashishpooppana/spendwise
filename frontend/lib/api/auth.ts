import type { LoginRequest, RegisterRequest, LoginResponse, User, ApiResponse } from "@/lib/types";
import { USE_MOCK, apiRequest, mockDelay, mockResponse, setAuthToken, clearAuthToken } from "./client";
import { mockUser } from "@/lib/mock/data";

export async function login(data: LoginRequest): Promise<ApiResponse<LoginResponse>> {
  if (USE_MOCK) {
    await mockDelay(500);
    const token = "mock_jwt_token_" + Date.now();
    setAuthToken(token);
    return mockResponse({ user: mockUser, token }, "Login successful");
  }
  const res = await apiRequest<LoginResponse>("/auth/login/", {
    method: "POST",
    body: JSON.stringify(data),
  });
  console.log("res", res);
  if (res.data.token) setAuthToken(res.data.token);
  return res;
}

export async function register(data: RegisterRequest): Promise<ApiResponse<LoginResponse>> {
  if (USE_MOCK) {
    await mockDelay(500);
    const user: User = { ...mockUser, name: data.name, email: data.email, phone: data.phone };
    const token = "mock_jwt_token_" + Date.now();
    setAuthToken(token);
    return mockResponse({ user, token }, "Registration successful");
  }
  const res = await apiRequest<LoginResponse>("/auth/register/", {
    method: "POST",
    body: JSON.stringify(data),
  });
  if (res.data.token) setAuthToken(res.data.token);
  return res;
}

export async function forgotPassword(email: string): Promise<ApiResponse<{ message: string }>> {
  if (USE_MOCK) {
    await mockDelay(500);
    return mockResponse({ message: "OTP sent to your email/phone" });
  }
  return apiRequest("/auth/forgot-password/", {
    method: "POST",
    body: JSON.stringify({ email }),
  });
}

export async function verifyOtp(email: string, otp: string): Promise<ApiResponse<{ message: string }>> {
  if (USE_MOCK) {
    await mockDelay(500);
    if (otp === "123456") {
      return mockResponse({ message: "OTP verified successfully" });
    }
    return { success: false, data: { message: "Invalid OTP" }, message: "Invalid OTP" };
  }
  return apiRequest("/auth/verify-otp/", {
    method: "POST",
    body: JSON.stringify({ email, otp }),
  });
}

export async function resetPassword(email: string, otp: string, newPassword: string): Promise<ApiResponse<{ message: string }>> {
  if (USE_MOCK) {
    await mockDelay(500);
    return mockResponse({ message: "Password reset successful" });
  }
  return apiRequest("/auth/reset-password/", {
    method: "POST",
    body: JSON.stringify({ email, otp, newPassword }),
  });
}

export async function getProfile(): Promise<ApiResponse<User>> {
  if (USE_MOCK) {
    await mockDelay(200);
    return mockResponse(mockUser);
  }
  return apiRequest<User>("/auth/profile/");
}

export async function updateProfile(data: Partial<User>): Promise<ApiResponse<User>> {
  if (USE_MOCK) {
    await mockDelay(300);
    return mockResponse({ ...mockUser, ...data });
  }
  return apiRequest<User>("/auth/profile/", {
    method: "PUT",
    body: JSON.stringify(data),
  });
}

export async function logout(): Promise<void> {
  if (!USE_MOCK) {
    await apiRequest("/auth/logout/", { method: "POST" }).catch(() => {});
  }
  clearAuthToken();
}
