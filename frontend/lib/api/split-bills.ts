import type { SplitBill, ShareGroup, ApiResponse } from "@/lib/types";
import { USE_MOCK, apiRequest, mockDelay, mockResponse } from "./client";
import { mockSplitBills, mockShareGroups } from "@/lib/mock/data";

// --- Split Bills ---
export async function getSplitBills(): Promise<ApiResponse<SplitBill[]>> {
  if (USE_MOCK) { await mockDelay(300); return mockResponse([...mockSplitBills]); }
  return apiRequest<SplitBill[]>("/split-bills");
}

export async function getSplitBill(id: string): Promise<ApiResponse<SplitBill>> {
  if (USE_MOCK) {
    await mockDelay(200);
    const bill = mockSplitBills.find((b) => b.id === id);
    if (!bill) return { success: false, data: {} as SplitBill, message: "Not found" };
    return mockResponse(bill);
  }
  return apiRequest<SplitBill>(`/split-bills/${id}`);
}

export async function createSplitBill(data: Partial<SplitBill>): Promise<ApiResponse<SplitBill>> {
  if (USE_MOCK) {
    await mockDelay(400);
    const bill: SplitBill = {
      id: "sb" + Date.now(), title: data.title || "", description: data.description,
      totalAmount: data.totalAmount || 0, splitType: data.splitType || "equal",
      participants: data.participants || [], createdBy: "u1",
      groupId: data.groupId, date: new Date().toISOString(),
      isSettled: false, createdAt: new Date().toISOString(),
    };
    mockSplitBills.push(bill);
    return mockResponse(bill, "Split bill created");
  }
  return apiRequest<SplitBill>("/split-bills", { method: "POST", body: JSON.stringify(data) });
}

export async function deleteSplitBill(id: string): Promise<ApiResponse<{ message: string }>> {
  if (USE_MOCK) {
    await mockDelay(300);
    const idx = mockSplitBills.findIndex((b) => b.id === id);
    if (idx !== -1) mockSplitBills.splice(idx, 1);
    return mockResponse({ message: "Deleted" });
  }
  return apiRequest(`/split-bills/${id}`, { method: "DELETE" });
}

// --- Share Groups ---
export async function getShareGroups(): Promise<ApiResponse<ShareGroup[]>> {
  if (USE_MOCK) { await mockDelay(300); return mockResponse([...mockShareGroups]); }
  return apiRequest<ShareGroup[]>("/share-groups");
}

export async function getShareGroup(id: string): Promise<ApiResponse<ShareGroup>> {
  if (USE_MOCK) {
    await mockDelay(200);
    const group = mockShareGroups.find((g) => g.id === id);
    if (!group) return { success: false, data: {} as ShareGroup, message: "Not found" };
    return mockResponse(group);
  }
  return apiRequest<ShareGroup>(`/share-groups/${id}`);
}

export async function createShareGroup(data: Partial<ShareGroup>): Promise<ApiResponse<ShareGroup>> {
  if (USE_MOCK) {
    await mockDelay(400);
    const group: ShareGroup = {
      id: "sg" + Date.now(), name: data.name || "", description: data.description,
      members: data.members || [], bills: [], createdBy: "u1", createdAt: new Date().toISOString(),
    };
    mockShareGroups.push(group);
    return mockResponse(group, "Group created");
  }
  return apiRequest<ShareGroup>("/share-groups", { method: "POST", body: JSON.stringify(data) });
}

export async function deleteShareGroup(id: string): Promise<ApiResponse<{ message: string }>> {
  if (USE_MOCK) {
    await mockDelay(300);
    const idx = mockShareGroups.findIndex((g) => g.id === id);
    if (idx !== -1) mockShareGroups.splice(idx, 1);
    return mockResponse({ message: "Deleted" });
  }
  return apiRequest(`/share-groups/${id}`, { method: "DELETE" });
}
