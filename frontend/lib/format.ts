// Utility formatting functions for the finance tracker

export function formatCurrency(amount: number, compact = false): string {
  if (compact) {
    if (amount >= 10000000) return `₹${(amount / 10000000).toFixed(1)}Cr`;
    if (amount >= 100000) return `₹${(amount / 100000).toFixed(1)}L`;
    if (amount >= 1000) return `₹${(amount / 1000).toFixed(1)}K`;
  }
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

export function formatDate(dateStr: string, format: "short" | "long" | "relative" = "short"): string {
  const date = new Date(dateStr);
  const now = new Date();

  if (format === "relative") {
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return "Just now";
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
  }

  if (format === "long") {
    return date.toLocaleDateString("en-IN", {
      weekday: "short", day: "numeric", month: "long", year: "numeric",
    });
  }

  return date.toLocaleDateString("en-IN", {
    day: "2-digit", month: "short", year: "numeric",
  });
}

export function formatDateTime(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString("en-IN", {
    day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit",
  });
}

export function getCategoryLabel(category: string): string {
  const labels: Record<string, string> = {
    groceries: "Groceries", rent: "Rent", utilities: "Utilities",
    food_dining: "Food & Dining", transport: "Transport", entertainment: "Entertainment",
    shopping: "Shopping", health: "Health", education: "Education",
    salary: "Salary", freelance: "Freelance", investment_returns: "Investment Returns",
    refund: "Refund", gift: "Gift", reimbursement: "Reimbursement",
    cashback: "Cashback",
    subscriptions: "Subscriptions", insurance: "Insurance", travel: "Travel",
    personal_care: "Personal Care", atm: "ATM", other: "Other",
  };
  return labels[category] || category;
}

export function getMethodLabel(method: string): string {
  const labels: Record<string, string> = {
    upi: "UPI", credit_card: "Credit Card", debit_card: "Debit Card",
    bank_transfer: "Bank Transfer", cash: "Cash", atm: "ATM",
    net_banking: "Net Banking", wallet: "Wallet",
  };
  return labels[method] || method;
}

export function getPercentageChange(current: number, previous: number): number {
  if (previous === 0) return current > 0 ? 100 : 0;
  return Number((((current - previous) / previous) * 100).toFixed(1));
}
