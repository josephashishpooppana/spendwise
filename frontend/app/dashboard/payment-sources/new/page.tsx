"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import type { PaymentSource, PaymentSourceType } from "@/lib/types";
import * as paymentSourcesApi from "@/lib/api/payment-sources";
import * as paymentMethodsApi from "@/lib/api/payment-methods";
import { toast } from "sonner";

// Backend source type key -> frontend type (for form conditionals)
const SOURCE_KEY_TO_FRONTEND_TYPE: Record<string, PaymentSourceType> = {
  BANK: "bank",
  CREDIT_CARD: "credit_card",
  DEBIT_CARD: "debit_card",
  WALLET: "wallet",
  CASH: "cash",
};

const CARD_NETWORKS = ["Visa", "Mastercard", "RuPay", "Amex", "Other"];

export default function NewPaymentSourcePage() {
  const router = useRouter();
  const [sourceTypes, setSourceTypes] = useState<{ key: string; label: string }[]>([]);
  const [loadingTypes, setLoadingTypes] = useState(true);
  const [sourceTypeKey, setSourceTypeKey] = useState(""); // backend key (BANK, CREDIT_CARD, etc.)

  const [name, setName] = useState("");
  const [initialBalance, setInitialBalance] = useState(0);
  const [currency, setCurrency] = useState("INR");
  // Bank
  const [bankName, setBankName] = useState("");
  const [accountNumber, setAccountNumber] = useState("");
  const [ifsc, setIfsc] = useState("");
  // Credit / Debit card
  const [cardBankName, setCardBankName] = useState("");
  const [lastFourDigits, setLastFourDigits] = useState("");
  const [cardNetwork, setCardNetwork] = useState("");
  const [creditLimit, setCreditLimit] = useState(0);
  const [linkedBankSourceId, setLinkedBankSourceId] = useState("");
  const [bankSources, setBankSources] = useState<PaymentSource[]>([]);
  // Wallet
  const [walletName, setWalletName] = useState("");
  const [upiId, setUpiId] = useState("");
  const [submitting, setSubmitting] = useState(false);

  // Derive frontend type for form conditionals
  const type: PaymentSourceType = (sourceTypeKey ? SOURCE_KEY_TO_FRONTEND_TYPE[sourceTypeKey] : undefined) ?? "bank";

  useEffect(() => {
    let cancelled = false;
    paymentMethodsApi.getSourceTypes().then((res) => {
      if (cancelled) return;
      setLoadingTypes(false);
      if (res.success && res.data && res.data.length > 0) {
        setSourceTypes(res.data);
        if (!sourceTypeKey) setSourceTypeKey(res.data[0].key);
      } else {
        toast.error("Failed to load source types");
      }
    });
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    (async () => {
      const res = await paymentSourcesApi.getPaymentSources({ all: true });
      if (res.success && res.data) {
        setBankSources(res.data.filter((s) => s.type === "bank"));
      }
    })();
  }, []);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setSubmitting(true);

    const form = e.currentTarget;
    const getVal = (id: string) => (form.querySelector(`#${id}`) as HTMLInputElement | null)?.value ?? "";
    const getNum = (id: string) => {
      const v = getVal(id);
      return v === "" ? 0 : Number(v);
    };

    const formName = getVal("name").trim();
    const formInitialBalance = getNum("initialBalance");
    const formCurrency = getVal("currency").trim() || "INR";
    const formBankName = getVal("bankName").trim();
    const formAccountNumber = getVal("accountNumber").trim();
    const formIfsc = getVal("ifsc").trim();
    const formCardBankName = getVal("cardBankName").trim();
    const formLastFourDigits = getVal("lastFourDigits").trim();
    const formCreditLimit = getNum("creditLimit");
    const formWalletName = getVal("walletName").trim();
    const formUpiId = getVal("upiId").trim();

    if (type === "debit_card" && !linkedBankSourceId.trim()) {
      toast.error("Debit card requires a linked bank account.");
      setSubmitting(false);
      return;
    }

    const payload = {
      name: formName,
      sourceType: sourceTypeKey,
      type,
      balance: type === "debit_card" ? 0 : formInitialBalance,
      currency: formCurrency,
      isActive: true,
      bankName: type === "credit_card" || type === "debit_card" ? formCardBankName : formBankName,
      accountNumber: formAccountNumber || undefined,
      ifsc: formIfsc || undefined,
      cardNetwork: cardNetwork || undefined,
      lastFourDigits: formLastFourDigits || undefined,
      creditLimit: formCreditLimit ? Number(formCreditLimit) : undefined,
      walletName: formWalletName || undefined,
      upiIds: formUpiId ? [formUpiId] : [],
      linkedBankSourceId:
        type === "credit_card" || type === "debit_card"
          ? (linkedBankSourceId.trim() || undefined)
          : undefined,
    };

    try {
      const res = await paymentSourcesApi.createPaymentSource(payload);

      if (res.success) {
          router.push("/dashboard/payment-sources");
          toast.success("Payment source added.");
      } else {
        toast.error(res.message ?? "Failed to add source.");
      }
    } catch {
      toast.error("Something went wrong. Try again.");
    } finally {
      setSubmitting(false);
    }
  }

  const balanceLabel =
    type === "credit_card"
      ? "Current balance (amount you owe; expenses increase this)"
      : type === "debit_card"
        ? null
        : "Initial balance (reduced by expenses, increased by income)";

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-xl mx-auto">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/dashboard/payment-sources">
            <ArrowLeft className="h-4 w-4" />
            <span className="sr-only">Back</span>
          </Link>
        </Button>
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Add payment source</h1>
          <p className="text-sm text-muted-foreground">
            Bank account, credit card, debit card, wallet, or physical cash. Balance updates when you add income or expenses.
          </p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Source details</CardTitle>
          <CardDescription>Choose type, fill in details, and set initial balance</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={onSubmit} className="flex flex-col gap-5">
            <div className="grid gap-2">
              <Label>Type</Label>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {loadingTypes ? (
                  <p className="text-sm text-muted-foreground col-span-full">Loading types…</p>
                ) : sourceTypes.length === 0 ? (
                  <p className="text-sm text-muted-foreground col-span-full">No source types found. Add them in Django admin.</p>
                ) : (
                  sourceTypes.map((st) => (
                    <button
                      key={st.key}
                      type="button"
                      onClick={() => setSourceTypeKey(st.key)}
                      className={`rounded-md border px-3 py-2 text-sm font-medium transition-colors ${
                        sourceTypeKey === st.key
                          ? "border-primary bg-primary text-primary-foreground"
                          : "border-input hover:bg-muted/50"
                      }`}
                    >
                      {st.label}
                    </button>
                  ))
                )}
              </div>
              <p className="text-xs text-muted-foreground">Options loaded from the database.</p>
            </div>

            <div className="grid gap-2">
              <Label htmlFor="name">Display name</Label>
              <Input
                id="name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder={
                  type === "bank"
                    ? "e.g. HDFC Savings"
                    : type === "credit_card"
                      ? "e.g. ICICI Credit Card"
                      : type === "debit_card"
                        ? "e.g. SBI Debit Card"
                        : type === "wallet"
                          ? "e.g. Google Pay"
                          : "e.g. Physical cash"
                }
                required
              />
            </div>

            {type !== "debit_card" && (
              <>
            <div className="grid gap-2">
              <Label htmlFor="initialBalance">{balanceLabel}</Label>
              <Input
                id="initialBalance"
                type="number"
                step="any"
                min={type === "credit_card" ? undefined : "0"}
                value={initialBalance}
                onChange={(e) => setInitialBalance(e.target.value === "" ? 0 : Number(e.target.value))}
                placeholder={type === "credit_card" ? "e.g. 0 or amount owed" : "e.g. 0"}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="currency">Currency</Label>
              <Input
                id="currency"
                value={currency}
                onChange={(e) => setCurrency(e.target.value)}
                placeholder="INR"
              />
            </div>
              </>
            )}
            {type === "debit_card" && (
              <p className="text-sm text-muted-foreground">
                Balance is taken from the linked bank account. No need to enter it here.
              </p>
            )}

            {type === "bank" && (
              <>
                <div className="grid gap-2">
                  <Label htmlFor="bankName">Bank name</Label>
                  <Input
                    id="bankName"
                    value={bankName}
                    onChange={(e) => setBankName(e.target.value)}
                    placeholder="e.g. HDFC Bank"
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="accountNumber">Account number</Label>
                  <Input
                    id="accountNumber"
                    value={accountNumber}
                    onChange={(e) => setAccountNumber(e.target.value)}
                    placeholder="Full number or last 4 digits (e.g. ****4521)"
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="ifsc">IFSC</Label>
                  <Input
                    id="ifsc"
                    value={ifsc}
                    onChange={(e) => setIfsc(e.target.value)}
                    placeholder="e.g. HDFC0001234"
                  />
                </div>
              </>
            )}

            {(type === "credit_card" || type === "debit_card") && (
              <>
                <div className="grid gap-2">
                  <Label htmlFor="cardBankName">Bank / Issuer (optional)</Label>
                  <Input
                    id="cardBankName"
                    value={cardBankName}
                    onChange={(e) => setCardBankName(e.target.value)}
                    placeholder="e.g. ICICI Bank, HDFC Bank"
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="linkedBankSourceId">
                    Linked bank account
                    {type === "debit_card" ? " (required)" : " (optional, for bill payment)"}
                  </Label>
                  {/* select should have same width as the input */}
                  
                  <Select
                    value={linkedBankSourceId || "none"}
                    onValueChange={(v) => setLinkedBankSourceId(v === "none" ? "" : v)}
                  >
                    <SelectTrigger id="linkedBankSourceId" className="w-full">
                      <SelectValue placeholder="Select bank account…" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="none">None</SelectItem>
                      {bankSources.length === 0 ? (
                        <SelectItem value="__no_banks__" disabled>
                          No bank accounts yet — add a bank account first
                        </SelectItem>
                      ) : (
                        bankSources.map((s) => (
                          <SelectItem key={s.id} value={s.id}>
                            {s.name}
                            {s.bankName ? ` (${s.bankName})` : ""}
                          </SelectItem>
                        ))
                      )}
                    </SelectContent>
                  </Select>
                  {type === "debit_card" && (
                    <p className="text-xs text-muted-foreground">
                      The account this debit card draws from. Expenses on this card will be linked to that account.
                      {bankSources.length === 0 && " Add a bank account first, then come back to add this debit card."}
                    </p>
                  )}
                  {type === "credit_card" && (
                    <p className="text-xs text-muted-foreground">
                      Optional: the account you use to pay this card&apos;s bill. Helps link repayments to expenses.
                    </p>
                  )}
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="lastFourDigits">Last 4 digits</Label>
                  <Input
                    id="lastFourDigits"
                    value={lastFourDigits}
                    onChange={(e) => setLastFourDigits(e.target.value.replace(/\D/g, "").slice(0, 4))}
                    placeholder="e.g. 3456"
                    maxLength={4}
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="cardNetwork">Card network</Label>
                  <div className="flex flex-wrap gap-2">
                    {CARD_NETWORKS.map((net) => (
                      <button
                        key={net}
                        type="button"
                        onClick={() => setCardNetwork(cardNetwork === net ? "" : net)}
                        className={`rounded-md border px-3 py-1.5 text-sm ${
                          cardNetwork === net
                            ? "border-primary bg-primary text-primary-foreground"
                            : "border-input hover:bg-muted/50"
                        }`}
                      >
                        {net}
                      </button>
                    ))}
                  </div>
                </div>
                {type === "credit_card" && (
                  <div className="grid gap-2">
                    <Label htmlFor="creditLimit">Credit limit (optional)</Label>
                    <Input
                      id="creditLimit"
                      type="number"
                      min="0"
                      step="any"
                      value={creditLimit}
                      onChange={(e) => setCreditLimit(Number(e.target.value))}
                      placeholder="e.g. 100000"
                    />
                  </div>
                )}
              </>
            )}

            {type === "wallet" && (
              <>
                <div className="grid gap-2">
                  <Label htmlFor="walletName">Wallet name</Label>
                  <Input
                    id="walletName"
                    value={walletName}
                    onChange={(e) => setWalletName(e.target.value)}
                    placeholder="e.g. Google Pay, Paytm"
                  />
                </div>
                <div className="grid gap-2">
                  <Label htmlFor="upiId">UPI ID</Label>
                  <Input
                    id="upiId"
                    value={upiId}
                    onChange={(e) => setUpiId(e.target.value)}
                    placeholder="e.g. user@okaxis"
                  />
                </div>
              </>
            )}

            {type === "cash" && (
              <p className="text-sm text-muted-foreground">
                Physical cash. Enter the current amount you have; it will be reduced when you add expenses from this source and increased when you add income to it.
              </p>
            )}

            <div className="flex gap-3 pt-2">
              <Button type="submit" disabled={submitting}>
                {submitting ? "Adding…" : "Add source"}
              </Button>
              <Button type="button" variant="outline" asChild>
                <Link href="/dashboard/payment-sources">Cancel</Link>
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
