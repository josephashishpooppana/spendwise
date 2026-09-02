import { USE_MOCK, apiRequest, mockDelay, mockResponse } from "./client";
import { PaymentSource } from "@/lib/types";
import type { PaymentSourceType } from "@/lib/types";
import { ApiResponse } from "@/lib/types";

// Frontend type (camelCase) -> backend sourceType (BANK, CREDIT_CARD, DEBIT_CARD, WALLET, CASH)
const TYPE_TO_SOURCE_TYPE: Record<PaymentSourceType, string> = {
  bank: "BANK",
  credit_card: "CREDIT_CARD",
  debit_card: "DEBIT_CARD",
  wallet: "WALLET",
  cash: "CASH",
};

// Backend sourceType key -> frontend type
const SOURCE_TYPE_KEY_TO_TYPE: Record<string, PaymentSourceType> = {
  BANK: "bank",
  CREDIT_CARD: "credit_card",
  DEBIT_CARD: "debit_card",
  WALLET: "wallet",
  CASH: "cash",
};

// get all payment sources
export async function getPaymentSources(params?: { all?: boolean }): Promise<ApiResponse<PaymentSource[]>> {
    if (USE_MOCK) {
        await mockDelay(200);
        return mockResponse([
            { id: "ps1", name: "HDFC Bank", type: "bank", balance: 100000, currency: "INR", isActive: true, createdAt: new Date().toISOString() },
            { id: "ps2", name: "ICICI Bank", type: "bank", balance: 50000, currency: "INR", isActive: true, createdAt: new Date().toISOString() },
            { id: "ps3", name: "SBI Bank", type: "bank", balance: 25000, currency: "INR", isActive: true, createdAt: new Date().toISOString() },
        ]);
    }

    const qs = params?.all ? "?all=1" : ""; 
    return apiRequest<PaymentSource[]>(`/finance/payment-sources/${qs}`);
}


// get one specific payment source
export async function getPaymentSource(id: string): Promise<ApiResponse<PaymentSource>> {
    if (USE_MOCK) {
        await mockDelay(200);
        const sources = (await getPaymentSources()).data;
        const source = sources.find((s) => s.id === id);
        if (!source) return { success: false, data: {} as PaymentSource, message: "Not found" };
        return mockResponse(source);
    }
    return apiRequest<PaymentSource>(`/finance/payment-sources/${id}/`);
}


// create a new payment source
// Accepts sourceType (backend key, e.g. BANK) or type (frontend); sends sourceType to backend.
export async function createPaymentSource(data: Partial<PaymentSource> & { name: string; sourceType?: string; type?: PaymentSource["type"] }): Promise<ApiResponse<PaymentSource>> {
    if (USE_MOCK) {
        await mockDelay(200);
        const type = data.type ?? (data.sourceType ? SOURCE_TYPE_KEY_TO_TYPE[data.sourceType] : undefined) ?? "bank";
        const source: PaymentSource = { id: "ps" + Date.now(), name: data.name || "", type, balance: data.balance || 0, currency: data.currency || "INR", isActive: true, createdAt: new Date().toISOString() };
        return mockResponse(source, "Payment source created");
    }
    const sourceType = data.sourceType ?? (data.type ? TYPE_TO_SOURCE_TYPE[data.type as PaymentSourceType] : undefined) ?? "BANK";
    const body = {
        name: data.name ?? "",
        sourceType,
        bankName: data.bankName ?? undefined,
        balance: data.balance ?? 0,
        currency: data.currency ?? undefined,
        isActive: data.isActive ?? true,
        accountNumber: data.accountNumber ?? undefined,
        ifsc: data.ifsc ?? undefined,
        cardNetwork: data.cardNetwork ?? undefined,
        lastFourDigits: data.lastFourDigits ?? undefined,
        creditLimit: data.creditLimit ?? undefined,
        walletName: data.walletName ?? undefined,
        upiIds: data.upiIds ?? undefined,
        linkedBankSourceId: data.linkedBankSourceId ?? undefined,
    };

    return apiRequest<PaymentSource>("/finance/payment-sources/create/", { method: "POST", body: JSON.stringify(body) });
}


// update a payment source
export async function updatePaymentSource(id: string, data: Partial<PaymentSource>): Promise<ApiResponse<PaymentSource>> {
    if (USE_MOCK) {
        await mockDelay(200);
        const source = (await getPaymentSource(id)).data;
        if (!source) return { success: false, data: {} as PaymentSource, message: "Not found" };
        return mockResponse(source, "Payment source updated");
    }
    return apiRequest<PaymentSource>(`/finance/payment-sources/${id}/`, { method: "PUT", body: JSON.stringify(data) });
}


// delete a payment source
export async function deletePaymentSource(id: string): Promise<ApiResponse<{ message: string }>> {
    if (USE_MOCK) {
        await mockDelay(200);
        return mockResponse({ message: "Payment source deleted" });
    }
    return apiRequest<{ message: string }>(`/finance/payment-sources/${id}/`, { method: "DELETE" });
}
