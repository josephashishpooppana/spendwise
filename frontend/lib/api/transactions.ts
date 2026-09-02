import type { Transaction, TransactionFilters, ApiResponse } from "@/lib/types";
import { USE_MOCK, apiRequest, apiUpload, mockDelay, mockResponse, mockPaginatedResponse } from "./client";
import { mockTransactions } from "@/lib/mock/data";

export async function getTransactions(filters?: TransactionFilters): Promise<ApiResponse<Transaction[]>> {
  if (USE_MOCK) {
    await mockDelay(300);
    let filtered = [...mockTransactions];

    if (filters?.type) filtered = filtered.filter((t) => t.type === filters.type);
    if (filters?.category) filtered = filtered.filter((t) => t.category === filters.category);
    if (filters?.paymentMethodType) filtered = filtered.filter((t) => t.paymentMethodType === filters.paymentMethodType);
    if (filters?.paymentSourceId) filtered = filtered.filter((t) => t.paymentSourceId === filters.paymentSourceId);
    if (filters?.search) {
      const s = filters.search.toLowerCase();
      filtered = filtered.filter((t) => t.description.toLowerCase().includes(s) || t.category.toLowerCase().includes(s));
    }
    if (filters?.dateFrom) filtered = filtered.filter((t) => t.date >= filters.dateFrom!);
    if (filters?.dateTo) filtered = filtered.filter((t) => t.date <= filters.dateTo!);

    const sortBy = filters?.sortBy || "date";
    const sortOrder = filters?.sortOrder || "desc";
    filtered.sort((a, b) => {
      const aVal = a[sortBy as keyof Transaction] as string;
      const bVal = b[sortBy as keyof Transaction] as string;
      return sortOrder === "desc" ? (bVal > aVal ? 1 : -1) : (aVal > bVal ? 1 : -1);
    });

    const page = filters?.page || 1;
    const limit = filters?.limit || 20;
    const start = (page - 1) * limit;
    const paged = filtered.slice(start, start + limit);

    return mockPaginatedResponse(paged, page, limit, filtered.length);
  }

  const params = new URLSearchParams();
  if (filters) {
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined) params.append(key, String(value));
    });
  }
  return apiRequest<Transaction[]>(`/finance/transactions/?${params.toString()}`);
}

export async function getTransaction(id: string): Promise<ApiResponse<Transaction>> {
  if (USE_MOCK) {
    await mockDelay(200);
    const transaction = mockTransactions.find((t) => t.id === id);
    if (!transaction) return { success: false, data: {} as Transaction, message: "Transaction not found" };
    return mockResponse(transaction);
  }
  return apiRequest<Transaction>(`/finance/transactions/${id}`);
}

export async function createTransaction(data: Partial<Transaction>): Promise<ApiResponse<Transaction>> {
  if (USE_MOCK) {
    await mockDelay(400);
    const newTransaction: Transaction = {
      id: "t" + Date.now(),
      type: data.type || "expense",
      amount: data.amount || 0,
      currency: "INR",
      category: data.category || "other",
      description: data.description || "",
      date: data.date || new Date().toISOString(),
      paymentMethodId: data.paymentMethodId || "pm1",
      paymentMethodName: data.paymentMethodName || "UPI",
      paymentMethodType: data.paymentMethodType || "upi",
      paymentSourceId: data.paymentSourceId || "ps1",
      paymentSourceName: data.paymentSourceName || "HDFC Bank Savings",
      paymentSourceType: data.paymentSourceType || "bank",
      notes: data.notes,
      cashback: data.cashback,
      cashbackSource: data.cashbackSource,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    mockTransactions.unshift(newTransaction);
    return mockResponse(newTransaction, "Transaction created");
  }
  return apiRequest<Transaction>("/finance/transactions/create/", {
    method: "POST",
    body: JSON.stringify(data),
  });
}

export async function updateTransaction(id: string, data: Partial<Transaction>): Promise<ApiResponse<Transaction>> {
  if (USE_MOCK) {
    await mockDelay(300);
    const idx = mockTransactions.findIndex((t) => t.id === id);
    if (idx === -1) return { success: false, data: {} as Transaction, message: "Not found" };
    mockTransactions[idx] = { ...mockTransactions[idx], ...data, updatedAt: new Date().toISOString() };
    return mockResponse(mockTransactions[idx], "Transaction updated");
  }
  return apiRequest<Transaction>(`/finance/transactions/${id}/`, {
    method: "PUT",
    body: JSON.stringify(data),
  });
}

export async function deleteTransaction(id: string): Promise<ApiResponse<{ message: string }>> {
  if (USE_MOCK) {
    await mockDelay(300);
    const idx = mockTransactions.findIndex((t) => t.id === id);
    if (idx !== -1) mockTransactions.splice(idx, 1);
    return mockResponse({ message: "Transaction deleted" });
  }
  return apiRequest(`/finance/transactions/${id}`, { method: "DELETE" });
}

export async function scanReceipt(file: File): Promise<ApiResponse<Partial<Transaction>>> {
  if (USE_MOCK) {
    await mockDelay(1500);
    return mockResponse({
      amount: 1250,
      description: "Scanned Receipt - Store Purchase",
      category: "shopping" as const,
      date: new Date().toISOString(),
    }, "Receipt scanned successfully");
  }
  const formData = new FormData();
  formData.append("receipt", file);
  return apiUpload<Partial<Transaction>>("/transactions/scan-receipt", formData);
}
