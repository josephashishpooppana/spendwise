import type { Notification, ApiResponse } from "@/lib/types";
import { USE_MOCK, apiRequest, mockDelay, mockResponse } from "./client";
import { mockNotifications } from "@/lib/mock/data";

export async function getNotifications(): Promise<ApiResponse<Notification[]>> {
  if (USE_MOCK) {
    await mockDelay(200);
    return mockResponse([...mockNotifications].sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()));
  }
  return apiRequest<Notification[]>("/notifications");
}

export async function getUnreadCount(): Promise<ApiResponse<{ count: number }>> {
  if (USE_MOCK) {
    await mockDelay(100);
    const count = mockNotifications.filter((n) => !n.isRead).length;
    return mockResponse({ count });
  }
  return apiRequest<{ count: number }>("/notifications/unread-count");
}

export async function markAsRead(id: string): Promise<ApiResponse<Notification>> {
  if (USE_MOCK) {
    await mockDelay(200);
    const idx = mockNotifications.findIndex((n) => n.id === id);
    if (idx !== -1) mockNotifications[idx].isRead = true;
    return mockResponse(mockNotifications[idx]);
  }
  return apiRequest<Notification>(`/notifications/${id}/read`, { method: "PUT" });
}

export async function markAllAsRead(): Promise<ApiResponse<{ message: string }>> {
  if (USE_MOCK) {
    await mockDelay(300);
    mockNotifications.forEach((n) => (n.isRead = true));
    return mockResponse({ message: "All notifications marked as read" });
  }
  return apiRequest("/notifications/read-all", { method: "PUT" });
}
