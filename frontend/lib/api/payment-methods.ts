import type { PaymentMethod, PaymentSource, PaymentApp, ApiResponse } from "@/lib/types";
import type { PaymentMethodType } from "@/lib/types";
import { USE_MOCK, apiRequest, mockDelay, mockResponse } from "./client";
import { mockPaymentMethods, mockPaymentSources } from "@/lib/mock/data";

// Backend method key -> display label (for Apps management UI)
export const BACKEND_METHOD_LABELS: Record<string, string> = {
  UPI: "UPI",
  CASH: "Cash",
  ATM: "ATM",
  CREDIT_CARD: "Credit Card",
  DEBIT_CARD: "Debit Card",
  WALLET: "Wallet",
  NET_BANKING: "Net Banking",
  CHECK: "Check",
  TRANSFER: "Bank Transfer",
  OTHER: "Other",
};

// Backend method key -> allowed source types for "Add source" in app
export const METHOD_TO_SOURCE_TYPES_FRONTEND: Record<string, string[]> = {
  UPI: ["CREDIT_CARD", "DEBIT_CARD"],
  IMPS: ["BANK"],
  NEFT: ["BANK"],
  RTGS: ["BANK"],
  NACH: ["BANK"],
  WALLET: ["WALLET"],
  TRANSFER: ["BANK"],
};

// export const METHOD_TO_SOURCE_TYPES_FRONTEND: Record<string, string[]> = {
//   UPI: ["CREDIT_CARD", "DEBIT_CARD", "WALLET"],
//   CREDIT_CARD: ["CREDIT_CARD"],
//   DEBIT_CARD: ["DEBIT_CARD"],
//   WALLET: ["WALLET"],
//   NET_BANKING: ["BANK"],
//   CASH: ["CASH"],
//   ATM: ["BANK"],
//   TRANSFER: ["BANK"],
//   CHECK: ["BANK"],
//   OTHER: ["BANK", "CREDIT_CARD", "DEBIT_CARD", "WALLET", "CASH"],
// };

export const SOURCE_TYPE_LABELS: Record<string, string> = {
  BANK: "Bank Account",
  CREDIT_CARD: "Credit Card",
  DEBIT_CARD: "Debit Card",
  WALLET: "Digital Wallet",
  CASH: "Physical Cash",
};

// --- Source Types (from DB, for payment method form) ---
export interface SourceTypeOption {
  key: string;
  label: string;
}

export async function getSourceTypes(): Promise<ApiResponse<SourceTypeOption[]>> {
  if (USE_MOCK) {
    await mockDelay(150);
    return mockResponse([
      { key: "BANK", label: "Bank Account" },
      { key: "CREDIT_CARD", label: "Credit Card" },
      { key: "DEBIT_CARD", label: "Debit Card" },
      { key: "WALLET", label: "Digital Wallet" },
      { key: "CASH", label: "Physical Cash" },
    ]);
  }
  return apiRequest<SourceTypeOption[]>("/finance/source-types/");
}

// Frontend PaymentMethodType -> backend method key for filtering sources
export const METHOD_TYPE_TO_BACKEND_KEY: Record<PaymentMethodType, string> = {
  upi: "UPI",
  credit_card: "CREDIT_CARD",
  debit_card: "DEBIT_CARD",
  bank_transfer: "TRANSFER",
  cash: "CASH",
  atm: "ATM",
  net_banking: "NET_BANKING",
  wallet: "WALLET",
  other: "OTHER",
};

export const BACKEND_KEY_TO_TYPE: Record<string, PaymentMethodType> = Object.fromEntries(
  Object.entries(METHOD_TYPE_TO_BACKEND_KEY).map(([type, key]) => [key, type as PaymentMethodType])
) as Record<string, PaymentMethodType>;

// --- Payment Apps ---
export async function getPaymentApps(params?: { all?: boolean }): Promise<ApiResponse<PaymentApp[]>> {
  if (USE_MOCK) {
    await mockDelay(200);
    return mockResponse([
      { id: "app1", name: "Google Pay", supportedMethods: ["UPI", "WALLET"], isActive: true, createdAt: new Date().toISOString() },
      { id: "app2", name: "PhonePe", supportedMethods: ["UPI", "WALLET"], isActive: true, createdAt: new Date().toISOString() },
      { id: "app3", name: "Paytm", supportedMethods: ["UPI", "WALLET"], isActive: true, createdAt: new Date().toISOString() },
      { id: "app4", name: "CRED", supportedMethods: ["UPI", "CREDIT_CARD"], isActive: true, createdAt: new Date().toISOString() },
    ]);
  }
  const qs = params?.all ? "?all=1" : "";
  return apiRequest<PaymentApp[]>(`/finance/payment-apps/${qs}`);
}

export async function getPaymentApp(id: string): Promise<ApiResponse<PaymentApp>> {
  if (USE_MOCK) {
    await mockDelay(200);
    const apps = (await getPaymentApps()).data;
    const app = apps.find((a) => a.id === id);
    if (!app) return { success: false, data: {} as PaymentApp, message: "Not found" };
    return mockResponse(app);
  }
  return apiRequest<PaymentApp>(`/finance/payment-apps/${id}/`);
}

export async function createPaymentApp(data: { name: string; supportedMethodIds?: string[]; supportedMethods?: string[]; isActive?: boolean }): Promise<ApiResponse<PaymentApp>> {
  if (USE_MOCK) {
    await mockDelay(400);
    const app: PaymentApp = {
      id: "app" + Date.now(),
      name: data.name,
      supportedMethods: data.supportedMethods || [],
      supportedMethodIds: data.supportedMethodIds || [],
      isActive: data.isActive ?? true,
      createdAt: new Date().toISOString(),
    };
    return mockResponse(app, "App created");
  }
  return apiRequest<PaymentApp>("/finance/payment-apps/create/", { method: "POST", body: JSON.stringify(data) });
}

export async function updatePaymentApp(id: string, data: Partial<{ name: string; supportedMethodIds: string[]; supportedMethods: string[]; isActive: boolean }>): Promise<ApiResponse<PaymentApp>> {
  if (USE_MOCK) {
    await mockDelay(300);
    const apps = (await getPaymentApps()).data as PaymentApp[];
    const idx = apps.findIndex((a) => a.id === id);
    if (idx === -1) return { success: false, data: {} as PaymentApp, message: "Not found" };
    (apps as PaymentApp[])[idx] = { ...apps[idx], ...data };
    return mockResponse(apps[idx], "Updated");
  }
  return apiRequest<PaymentApp>(`/finance/payment-apps/${id}/`, { method: "PUT", body: JSON.stringify(data) });
}

export async function deletePaymentApp(id: string): Promise<ApiResponse<{ message: string }>> {
  if (USE_MOCK) {
    await mockDelay(300);
    return mockResponse({ message: "Deleted" });
  }
  return apiRequest<{ message: string }>(`/finance/payment-apps/${id}/`, { method: "DELETE" });
}

// --- Payment Methods ---
export async function getPaymentMethods(params?: { appId?: string | null; management?: boolean }): Promise<ApiResponse<PaymentMethod[]>> {
  if (USE_MOCK) {
    await mockDelay(200);
    const list = [...mockPaymentMethods];
    if (params?.appId && params.appId !== "none") {
      const app = (await getPaymentApps()).data.find((a) => a.id === params.appId);
      if (app?.supportedMethods?.length) {
        const set = new Set(app.supportedMethods.map((m) => m.toUpperCase()));
        return mockResponse(list.filter((pm) => set.has(METHOD_TYPE_TO_BACKEND_KEY[pm.type])));
      }
    }
    return mockResponse(list);
  }
  const search = new URLSearchParams();
  if (params?.appId != null) search.set("app_id", params.appId);
  if (params?.management) search.set("management", "1");
  const qs = search.toString();
  return apiRequest<PaymentMethod[]>(`/finance/payment-methods/${qs ? `?${qs}` : ""}`);
}

export async function getPaymentMethod(id: string): Promise<ApiResponse<PaymentMethod>> {
  if (USE_MOCK) {
    await mockDelay(200);
    const list = [...mockPaymentMethods];
    const pm = list.find((p) => p.id === id);
    if (!pm) return { success: false, data: {} as PaymentMethod, message: "Not found" };
    return mockResponse(pm);
  }
  return apiRequest<PaymentMethod>(`/finance/payment-methods/${id}/`);
}

export async function createPaymentMethod(data: {
  name: string;
  sourceTypeKeys?: string[];
  sourceTypeIds?: number[];
}): Promise<ApiResponse<PaymentMethod>> {
  if (USE_MOCK) {
    await mockDelay(400);
    const pm: PaymentMethod = {
      id: "pm" + Date.now(),
      type: "other",
      name: data.name,
      isActive: true,
      details: {},
      createdAt: new Date().toISOString(),
      key: undefined,
      isBuiltIn: false,
      allowedSourceTypes: data.sourceTypeKeys ?? [],
    };
    mockPaymentMethods.push(pm);
    return mockResponse(pm, "Payment method created");
  }
  return apiRequest<PaymentMethod>("/finance/payment-methods/create/", {
    method: "POST",
    body: JSON.stringify({
      name: data.name,
      sourceTypeKeys: data.sourceTypeKeys,
      sourceTypeIds: data.sourceTypeIds,
    }),
  });
}

export async function updatePaymentMethod(
  id: string,
  data: Partial<{ name: string; sourceTypeKeys: string[]; sourceTypeIds: number[] }>
): Promise<ApiResponse<PaymentMethod>> {
  if (USE_MOCK) {
    await mockDelay(300);
    const idx = mockPaymentMethods.findIndex((p) => p.id === id);
    if (idx === -1) return { success: false, data: {} as PaymentMethod, message: "Not found" };
    mockPaymentMethods[idx] = { ...mockPaymentMethods[idx], ...data };
    return mockResponse(mockPaymentMethods[idx], "Updated");
  }
  return apiRequest<PaymentMethod>(`/finance/payment-methods/${id}/`, { method: "PUT", body: JSON.stringify(data) });
}

export async function togglePaymentMethod(id: string, isActive: boolean): Promise<ApiResponse<PaymentMethod>> {
  return updatePaymentMethod(id, { name: (await getPaymentMethod(id)).data?.name ?? "" });
}

export async function deletePaymentMethod(id: string): Promise<ApiResponse<{ message: string }>> {
  if (USE_MOCK) {
    await mockDelay(300);
    const idx = mockPaymentMethods.findIndex((p) => p.id === id);
    if (idx !== -1) mockPaymentMethods.splice(idx, 1);
    return mockResponse({ message: "Deleted" });
  }
  return apiRequest<{ message: string }>(`/finance/payment-methods/${id}/`, { method: "DELETE" });
}

// --- Payment Sources ---
export async function getPaymentSources(params?: {
  appId?: string | null;
  method?: PaymentMethodType;
  all?: boolean;
}): Promise<ApiResponse<PaymentSource[]>> {
  if (USE_MOCK) {
    await mockDelay(200);
    let list = [...mockPaymentSources];
    if (params?.appId && params.appId !== "none") {
      // App context: show wallet sources (e.g. Google Pay app → wallet sources)
      list = list.filter((s) => s.type === "wallet");
    }
    if (params?.method) {
      const backendKey = METHOD_TYPE_TO_BACKEND_KEY[params.method];
      const compatibleTypes = new Set<string>();
      if (backendKey === "UPI") compatibleTypes.add("credit_card").add("debit_card");
      else if (backendKey === "CREDIT_CARD") compatibleTypes.add("credit_card");
      else if (backendKey === "DEBIT_CARD") compatibleTypes.add("debit_card").add("bank");
      else if (backendKey === "WALLET") compatibleTypes.add("wallet");
      else if (backendKey === "CASH") compatibleTypes.add("cash");
      else compatibleTypes.add("bank").add("credit_card").add("debit_card").add("wallet").add("cash");
      list = list.filter((s) => compatibleTypes.has(s.type));
    }
    return mockResponse(list);
  }
  const search = new URLSearchParams();
  if (params?.appId != null) search.set("app_id", params.appId);
  if (params?.method != null) search.set("method", METHOD_TYPE_TO_BACKEND_KEY[params.method]);
  if (params?.all) search.set("all", "1");
  const qs = search.toString();
  return apiRequest<PaymentSource[]>(`/finance/payment-sources/${qs ? `?${qs}` : ""}`);
}

/** Link a payment source to an app for the given method(s). */
export async function linkSourceToApp(
  appId: string,
  sourceId: string,
  methodIds: string[]
): Promise<ApiResponse<{ linkedCount: number }>> {
  if (USE_MOCK) {
    await mockDelay(200);
    return mockResponse({ linkedCount: methodIds.length }, "Source linked");
  }
  const res = await apiRequest<{ linkedCount: number }>(`/finance/payment-apps/${appId}/link-source/`, {
    method: "POST",
    body: JSON.stringify({ sourceId, methodIds }),
  });
  return res;
}

/** Unlink a payment source from an app (optionally for specific method IDs). */
export async function unlinkSourceFromApp(
  appId: string,
  sourceId: string,
  methodIds?: string[]
): Promise<ApiResponse<{ unlinkedCount: number }>> {
  if (USE_MOCK) {
    await mockDelay(200);
    return mockResponse({ unlinkedCount: 1 }, "Source unlinked");
  }
  const res = await apiRequest<{ unlinkedCount: number }>(`/finance/payment-apps/${appId}/unlink-source/`, {
    method: "POST",
    body: JSON.stringify(methodIds != null ? { sourceId, methodIds } : { sourceId }),
  });
  return res;
}

const SOURCE_TYPE_TO_TYPE: Record<string, PaymentSource["type"]> = {
  BANK: "bank",
  CREDIT_CARD: "credit_card",
  DEBIT_CARD: "debit_card",
  WALLET: "wallet",
  CASH: "cash",
};

export async function createPaymentSource(data: Partial<PaymentSource> & { name: string; sourceType?: string; type?: PaymentSource["type"]; linkToAppId?: string; linkToMethodIds?: string[]; bankName?: string }): Promise<ApiResponse<PaymentSource>> {
  if (USE_MOCK) {
    await mockDelay(400);
    const type = data.type ?? (data.sourceType ? SOURCE_TYPE_TO_TYPE[data.sourceType] : undefined) ?? "bank";
    const ps: PaymentSource = {
      id: "ps" + Date.now(),
      name: data.name || "",
      type,
      balance: typeof data.balance === "number" ? data.balance : 0,
      currency: data.currency || "INR",
      isActive: data.isActive ?? true,
      createdAt: new Date().toISOString(),
      bankName: data.bankName,
      accountNumber: data.accountNumber,
      ifsc: data.ifsc,
      lastFourDigits: data.lastFourDigits,
      cardNetwork: data.cardNetwork,
      creditLimit: data.creditLimit,
      upiIds: data.upiIds,
      walletName: data.walletName,
    };
    mockPaymentSources.push(ps);
    return mockResponse(ps, "Payment source created");
  }
  return apiRequest<PaymentSource>("/finance/payment-sources/create/", { method: "POST", body: JSON.stringify(data) });
}

export async function updatePaymentSource(id: string, data: Partial<PaymentSource>): Promise<ApiResponse<PaymentSource>> {
  if (USE_MOCK) {
    await mockDelay(300);
    const idx = mockPaymentSources.findIndex((p) => p.id === id);
    if (idx === -1) return { success: false, data: {} as PaymentSource, message: "Not found" };
    mockPaymentSources[idx] = { ...mockPaymentSources[idx], ...data };
    return mockResponse(mockPaymentSources[idx], "Updated");
  }
  return apiRequest<PaymentSource>(`/finance/payment-sources/${id}/`, { method: "PUT", body: JSON.stringify(data) });
}

export async function togglePaymentSource(id: string, isActive: boolean): Promise<ApiResponse<PaymentSource>> {
  return updatePaymentSource(id, { isActive });
}

export async function deletePaymentSource(id: string): Promise<ApiResponse<{ message: string }>> {
  if (USE_MOCK) {
    await mockDelay(300);
    const idx = mockPaymentSources.findIndex((p) => p.id === id);
    if (idx !== -1) mockPaymentSources.splice(idx, 1);
    return mockResponse({ message: "Deleted" });
  }
  return apiRequest<{ message: string }>(`/finance/payment-sources/${id}/`, { method: "DELETE" });
}
