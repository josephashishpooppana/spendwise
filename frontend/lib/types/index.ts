// ============================================================
// Finance Tracker - Core Type Definitions
// ============================================================

// --- Enums ---

export type TransactionType = "income" | "expense";

export type PaymentMethodType =
  | "upi"
  | "credit_card"
  | "debit_card"
  | "bank_transfer"
  | "cash"
  | "atm"
  | "net_banking"
  | "wallet"
  | "other";

export type PaymentSourceType = "bank" | "credit_card" | "debit_card" | "wallet" | "cash";

export type SplitType = "equal" | "custom";

export type NotificationType =
  | "credit_card_due"
  | "bill_due"
  | "payment_reminder"
  | "split_settlement"
  | "cashback_received"
  | "system";

export type TransactionCategory =
  | "groceries"
  | "rent"
  | "utilities"
  | "food_dining"
  | "transport"
  | "entertainment"
  | "shopping"
  | "health"
  | "education"
  | "salary"
  | "freelance"
  | "investment_returns"
  | "refund"
  | "gift"
  | "reimbursement"
  | "cashback"
  | "subscriptions"
  | "insurance"
  | "travel"
  | "personal_care"
  | "other";

// --- Core Models ---

export interface User {
  id: string;
  name: string;
  email: string;
  phone: string;
  avatar?: string;
  preferences: UserPreferences;
  createdAt: string;
}

export interface UserPreferences {
  currency: string;
  dateFormat: string;
  theme: "light" | "dark" | "system";
  notificationPrefs: NotificationPreferences;
}

export interface NotificationPreferences {
  creditCardDue: boolean;
  billDue: boolean;
  paymentReminder: boolean;
  splitSettlement: boolean;
  cashbackReceived: boolean;
  systemUpdates: boolean;
}

export type CashbackKind = "fixed" | "percentage" | "reward_points";

export interface CashbackRecord {
  id: string;
  kind: CashbackKind;
  amount: number;
  percentage?: number | null;
  rewardPoints?: number | null;
  creditSourceId?: string | null;
  creditSourceName?: string | null;
  rewardAppId?: string | null;
  rewardAppName?: string | null;
  incomeTransactionId?: string | null;
}

export interface Transaction {
  id: string;
  type: TransactionType;
  amount: number;
  currency: string;
  category: TransactionCategory;
  description: string;
  date: string;
  paymentMethodId: string;
  paymentMethodName: string;
  paymentMethodType: PaymentMethodType;
  paymentSourceId: string;
  paymentSourceName: string;
  paymentSourceType: PaymentSourceType;
  paymentAppId?: string | null;
  paymentAppName?: string | null;
  notes?: string;
  isAutomated?: boolean;
  attachments?: string[];
  cashbackSource?: string;
  /** Full cashback record when present (object); legacy cashback amount as number. Can be array when multiple (cashback + reward points). */
  cashback?: number | CashbackRecord | CashbackRecord[] | null;
  /** For income from cashback: source expense id and description */
  cashbackFromExpenseId?: string;
  cashbackFromDescription?: string;
  splitInfo?: {
    splitBillId: string;
    shareAmount: number;
  };
  contactId?: string;
  contactName?: string;
  createdAt: string;
  updatedAt: string;
}

export interface PaymentMethod {
  id: string;
  type: PaymentMethodType;
  name: string;
  isActive: boolean;
  details: Record<string, string>;
  icon?: string;
  createdAt: string;
  /** Backend method key (e.g. UPI, CASH). Used for create/update. */
  key?: string;
  /** True for built-in methods; only custom methods can be edited/deleted. */
  isBuiltIn?: boolean;
  /** Source type keys this method supports (e.g. ["BANK"]). From DB, editable in admin. */
  allowedSourceTypes?: string[];
  /** Source type IDs when using SourceType FK; optional. */
  allowedSourceTypeIds?: number[];
}

export interface PaymentApp {
  id: string;
  name: string;
  supportedMethods: string[];
  /** PaymentMethod ids (so e.g. NEFT vs Bank Transfer can both be selected). */
  supportedMethodIds?: string[];
  isActive: boolean;
  createdAt: string;
}

export interface PaymentSource {
  id: string;
  name: string;
  type: PaymentSourceType;
  /** Current balance: reduced when expenses are added, increased when income is added. */
  balance: number;
  currency?: string;
  isActive: boolean;
  createdAt: string;
  /** App IDs this source is linked to (many-to-many via link table). */
  linkedAppIds?: string[];
  linkedAppNames?: string[];
  /** When fetching sources for an app, method IDs (for that app) this source is linked for. */
  linkedForAppMethodIds?: string[];
  // Card → linked bank account (required for debit, optional for credit)
  linkedBankSourceId?: string | null;
  linkedBankSourceName?: string | null;
  // Bank account
  bankName?: string;
  accountNumber?: string;
  ifsc?: string;
  // Credit / Debit card
  cardNetwork?: string;
  lastFourDigits?: string;
  /** Credit limit (for credit cards only). */
  creditLimit?: number;
  // Wallet
  walletName?: string;
  upiIds?: string[];
}

export interface Contact {
  id: string;
  name: string;
  phone: string;
  whatsappNumber?: string;
  email?: string;
  bankDetails: BankDetail[];
  upiIds: string[];
  avatar?: string;
  createdAt: string;
}

export interface BankDetail {
  bankName: string;
  accountNumber: string;
  ifsc: string;
  accountHolderName: string;
}

export interface SplitBill {
  id: string;
  title: string;
  description?: string;
  totalAmount: number;
  splitType: SplitType;
  participants: SplitParticipant[];
  createdBy: string;
  groupId?: string;
  date: string;
  isSettled: boolean;
  createdAt: string;
}

export interface SplitParticipant {
  contactId: string;
  contactName: string;
  amount: number;
  isPaid: boolean;
  paidDate?: string;
}

export interface ShareGroup {
  id: string;
  name: string;
  description?: string;
  members: GroupMember[];
  bills: string[]; // bill IDs
  createdBy: string;
  createdAt: string;
}

export interface GroupMember {
  contactId: string;
  contactName: string;
  balance: number; // positive = owed to them, negative = they owe
}

export interface Notification {
  id: string;
  type: NotificationType;
  title: string;
  message: string;
  isRead: boolean;
  dueDate?: string;
  relatedEntityId?: string;
  relatedEntityType?: string;
  createdAt: string;
}

// --- Analytics Types ---

export interface AnalyticsOverview {
  totalIncome: number;
  totalExpenses: number;
  netSavings: number;
  totalCashback: number;
  transactionCount: number;
  avgTransactionAmount: number;
  topCategory: string;
  topPaymentMethod: string;
}

export interface MethodBreakdown {
  method: PaymentMethodType;
  label: string;
  totalAmount: number;
  transactionCount: number;
  percentage: number;
  sources: SourceBreakdown[];
}

export interface SourceBreakdown {
  sourceId: string;
  sourceName: string;
  totalAmount: number;
  transactionCount: number;
  percentage: number;
}

export interface CategoryBreakdown {
  category: TransactionCategory;
  label: string;
  totalAmount: number;
  transactionCount: number;
  percentage: number;
  color: string;
}

export interface CashbackAnalytics {
  totalCashback: number;
  byMethod: { method: string; amount: number; percentage: number }[];
  bySource: { source: string; amount: number; percentage: number }[];
  bestMethod: string;
  bestSource: string;
}

export interface TrendDataPoint {
  period: string;
  income: number;
  expenses: number;
  savings: number;
  cashback: number;
}

export interface SmartSuggestion {
  id: string;
  type: "best_method" | "best_source" | "best_app" | "savings_tip";
  title: string;
  description: string;
  metric: string;
  metricValue: string;
}

export interface PeriodComparison {
  currentPeriod: { label: string; income: number; expenses: number; savings: number };
  previousPeriod: { label: string; income: number; expenses: number; savings: number };
  incomeChange: number;
  expenseChange: number;
  savingsChange: number;
}

// --- API Request/Response Types ---

export interface ApiResponse<T> {
  success: boolean;
  data: T;
  message?: string;
  pagination?: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface RegisterRequest {
  name: string;
  email: string;
  phone: string;
  password: string;
}

export interface LoginResponse {
  user: User;
  token: string;
}

export interface TransactionFilters {
  type?: TransactionType;
  category?: TransactionCategory;
  paymentMethodType?: PaymentMethodType;
  paymentSourceId?: string;
  dateFrom?: string;
  dateTo?: string;
  search?: string;
  page?: number;
  limit?: number;
  sortBy?: string;
  sortOrder?: "asc" | "desc";
}

export interface AnalyticsFilters {
  period: "week" | "month" | "quarter" | "year" | "custom";
  dateFrom?: string;
  dateTo?: string;
  type?: TransactionType;
}
