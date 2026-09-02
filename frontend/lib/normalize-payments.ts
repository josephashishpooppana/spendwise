import type { PaymentMethod, PaymentSource } from "@/lib/types";

/** Ensure API response is PaymentMethod[] (handles strings or snake_case from backend). */
export function normalizePaymentMethods(data: unknown): PaymentMethod[] {
  if (!Array.isArray(data) || data.length === 0) return [];
  const now = new Date().toISOString();
  const typeMap: Record<string, PaymentMethod["type"]> = {
    upi: "upi", cash: "cash", atm: "atm", credit_card: "credit_card",
    debit_card: "debit_card", wallet: "wallet", net_banking: "net_banking",
    bank_transfer: "bank_transfer",
  };
  const seenIds = new Set<string>();
  const ensureUniqueId = (baseId: string): string => {
    let id = baseId;
    let n = 0;
    while (seenIds.has(id)) id = `${baseId}_${++n}`;
    seenIds.add(id);
    return id;
  };
  return data.map((item, i): PaymentMethod => {
    if (typeof item === "string") {
      const id = ensureUniqueId(`pm_${i}`);
      const type = typeMap[item.toLowerCase().replace(/\s+/g, "_")] ?? "upi";
      return { id, type, name: item, isActive: true, details: {}, createdAt: now };
    }
    const raw = item as Record<string, unknown>;
    const isActive = raw.isActive ?? raw.is_active;
    const baseId = String(raw.id ?? `pm_${i}`);
    const id = ensureUniqueId(baseId);
    return {
      id,
      type: (typeMap[String(raw.type ?? "").toLowerCase()] ?? "upi") as PaymentMethod["type"],
      name: String(raw.name ?? raw.label ?? ""),
      isActive: typeof isActive === "boolean" ? isActive : true,
      details: (raw.details as Record<string, string>) ?? {},
      createdAt: String(raw.createdAt ?? raw.created_at ?? now),
    };
  });
}

/** Ensure API response is PaymentSource[] (handles strings or snake_case from backend). */
export function normalizePaymentSources(data: unknown): PaymentSource[] {
  if (!Array.isArray(data) || data.length === 0) return [];
  const now = new Date().toISOString();
  const typeMap: Record<string, PaymentSource["type"]> = {
    bank: "bank",
    credit_card: "credit_card",
    debit_card: "debit_card",
    wallet: "wallet",
    cash: "cash",
  };
  const seenIds = new Set<string>();
  const ensureUniqueId = (baseId: string): string => {
    let id = baseId;
    let n = 0;
    while (seenIds.has(id)) id = `${baseId}_${++n}`;
    seenIds.add(id);
    return id;
  };
  return data.map((item, i): PaymentSource => {
    if (typeof item === "string") {
      const id = ensureUniqueId(`ps_${i}`);
      return { id, name: item, type: "bank", balance: 0, currency: "INR", isActive: true, createdAt: now };
    }
    const raw = item as Record<string, unknown>;
    const isActive = raw.isActive ?? raw.is_active;
    const baseId = String(raw.id ?? `ps_${i}`);
    const id = ensureUniqueId(baseId);
    const balance = typeof raw.balance === "number" ? raw.balance : typeof raw.balance === "string" ? Number(raw.balance) || 0 : 0;
    const currency = typeof raw.currency === "string" ? raw.currency : "INR";
    return {
      id,
      name: String(raw.name ?? raw.label ?? ""),
      type: (typeMap[String(raw.type ?? "").toLowerCase()] ?? "bank") as PaymentSource["type"],
      balance,
      currency,
      isActive: typeof isActive === "boolean" ? isActive : true,
      createdAt: String(raw.createdAt ?? raw.created_at ?? now),
      bankName: raw.bankName != null ? String(raw.bankName) : raw.bank_name != null ? String(raw.bank_name) : undefined,
      linkedAppIds: Array.isArray(raw.linkedAppIds) ? (raw.linkedAppIds as string[]) : undefined,
      linkedAppNames: Array.isArray(raw.linkedAppNames) ? (raw.linkedAppNames as string[]) : undefined,
      linkedForAppMethodIds: Array.isArray(raw.linkedForAppMethodIds) ? (raw.linkedForAppMethodIds as string[]) : undefined,
      linkedBankSourceId: raw.linkedBankSourceId != null ? String(raw.linkedBankSourceId) : raw.linked_bank_source_id != null ? String(raw.linked_bank_source_id) : undefined,
      linkedBankSourceName: raw.linkedBankSourceName != null ? String(raw.linkedBankSourceName) : raw.linked_bank_source_name != null ? String(raw.linked_bank_source_name) : undefined,
      accountNumber: raw.accountNumber != null ? String(raw.accountNumber) : raw.account_number != null ? String(raw.account_number) : undefined,
      ifsc: raw.ifsc != null ? String(raw.ifsc) : undefined,
      lastFourDigits: raw.lastFourDigits != null ? String(raw.lastFourDigits) : raw.last_four_digits != null ? String(raw.last_four_digits) : undefined,
      cardNetwork: raw.cardNetwork != null ? String(raw.cardNetwork) : raw.card_network != null ? String(raw.card_network) : undefined,
      creditLimit: typeof raw.creditLimit === "number" ? raw.creditLimit : typeof raw.credit_limit === "number" ? raw.credit_limit : undefined,
      upiIds: Array.isArray(raw.upiIds) ? (raw.upiIds as string[]) : Array.isArray(raw.upi_ids) ? (raw.upi_ids as unknown[]) as string[] : undefined,
      walletName: raw.walletName != null ? String(raw.walletName) : raw.wallet_name != null ? String(raw.wallet_name) : undefined,
    };
  });
}
