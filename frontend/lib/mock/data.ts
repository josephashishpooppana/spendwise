import type {
  User,
  Transaction,
  PaymentMethod,
  PaymentSource,
  Contact,
  SplitBill,
  ShareGroup,
  Notification,
  AnalyticsOverview,
  MethodBreakdown,
  CategoryBreakdown,
  CashbackAnalytics,
  TrendDataPoint,
  SmartSuggestion,
  PeriodComparison,
} from "@/lib/types";

// --- Mock User ---
export const mockUser: User = {
  id: "u1",
  name: "Arjun Mehta",
  email: "arjun.mehta@gmail.com",
  phone: "+91 98765 43210",
  avatar: "",
  preferences: {
    currency: "INR",
    dateFormat: "DD/MM/YYYY",
    theme: "system",
    notificationPrefs: {
      creditCardDue: true,
      billDue: true,
      paymentReminder: true,
      splitSettlement: true,
      cashbackReceived: true,
      systemUpdates: true,
    },
  },
  createdAt: "2024-01-15T10:00:00Z",
};

// --- Payment Methods ---
export const mockPaymentMethods: PaymentMethod[] = [
  { id: "pm1", type: "upi", name: "UPI", isActive: true, details: {}, createdAt: "2024-01-15T10:00:00Z" },
  { id: "pm2", type: "credit_card", name: "Credit Card", isActive: true, details: {}, createdAt: "2024-01-15T10:00:00Z" },
  { id: "pm3", type: "debit_card", name: "Debit Card", isActive: true, details: {}, createdAt: "2024-01-15T10:00:00Z" },
  { id: "pm4", type: "cash", name: "Cash", isActive: true, details: {}, createdAt: "2024-01-15T10:00:00Z" },
  { id: "pm5", type: "bank_transfer", name: "Bank Transfer", isActive: true, details: {}, createdAt: "2024-01-15T10:00:00Z" },
  { id: "pm6", type: "atm", name: "ATM Withdrawal", isActive: true, details: {}, createdAt: "2024-01-15T10:00:00Z" },
  { id: "pm7", type: "net_banking", name: "Net Banking", isActive: true, details: {}, createdAt: "2024-01-15T10:00:00Z" },
  { id: "pm8", type: "wallet", name: "Wallet", isActive: false, details: {}, createdAt: "2024-01-15T10:00:00Z" },
];

// --- Payment Sources (balance: reduced by expenses, increased by income) ---
export const mockPaymentSources: PaymentSource[] = [
  { id: "ps1", name: "HDFC Bank Savings", type: "bank", balance: 85000, currency: "INR", bankName: "HDFC Bank", accountNumber: "****4521", ifsc: "HDFC0001234", upiIds: ["arjun@hdfcbank"], isActive: true, createdAt: "2024-01-15T10:00:00Z" },
  { id: "ps2", name: "SBI Salary Account", type: "bank", balance: 120000, currency: "INR", bankName: "State Bank of India", accountNumber: "****7890", ifsc: "SBIN0005678", upiIds: ["arjun@sbi"], isActive: true, createdAt: "2024-01-15T10:00:00Z" },
  { id: "ps3", name: "ICICI Credit Card", type: "credit_card", balance: -18450, currency: "INR", bankName: "ICICI Bank", lastFourDigits: "3456", cardNetwork: "Visa", creditLimit: 100000, isActive: true, createdAt: "2024-01-15T10:00:00Z" },
  { id: "ps4", name: "Axis Bank Credit Card", type: "credit_card", balance: -7299, currency: "INR", bankName: "Axis Bank", lastFourDigits: "6789", cardNetwork: "Visa", creditLimit: 75000, isActive: true, createdAt: "2024-01-15T10:00:00Z" },
  { id: "ps5", name: "Google Pay", type: "wallet", balance: 3500, currency: "INR", walletName: "Google Pay", upiIds: ["arjun@okaxis"], isActive: true, createdAt: "2024-01-15T10:00:00Z" },
  { id: "ps6", name: "PhonePe", type: "wallet", balance: 2100, currency: "INR", walletName: "PhonePe", upiIds: ["arjun@ybl"], isActive: true, createdAt: "2024-01-15T10:00:00Z" },
  { id: "ps7", name: "Paytm", type: "wallet", balance: 950, currency: "INR", walletName: "Paytm Wallet", upiIds: ["arjun@paytm"], isActive: true, createdAt: "2024-01-15T10:00:00Z" },
  { id: "ps8", name: "Physical cash", type: "cash", balance: 2500, currency: "INR", isActive: true, createdAt: "2024-01-15T10:00:00Z" },
];

// --- Contacts ---
export const mockContacts: Contact[] = [
  { id: "c1", name: "Priya Sharma", phone: "+91 99887 76655", whatsappNumber: "+91 99887 76655", email: "priya.sharma@email.com", bankDetails: [{ bankName: "HDFC Bank", accountNumber: "****1234", ifsc: "HDFC0001111", accountHolderName: "Priya Sharma" }], upiIds: ["priya@hdfcbank"], avatar: "", createdAt: "2024-02-01T10:00:00Z" },
  { id: "c2", name: "Rahul Verma", phone: "+91 88776 65544", whatsappNumber: "+91 88776 65544", email: "rahul.v@email.com", bankDetails: [{ bankName: "SBI", accountNumber: "****5678", ifsc: "SBIN0002222", accountHolderName: "Rahul Verma" }], upiIds: ["rahul@sbi", "rahul@okaxis"], avatar: "", createdAt: "2024-02-05T10:00:00Z" },
  { id: "c3", name: "Sneha Patel", phone: "+91 77665 54433", email: "sneha.p@email.com", bankDetails: [], upiIds: ["sneha@ybl"], avatar: "", createdAt: "2024-02-10T10:00:00Z" },
  { id: "c4", name: "Vikram Singh", phone: "+91 66554 43322", whatsappNumber: "+91 66554 43322", email: "vikram@email.com", bankDetails: [{ bankName: "ICICI Bank", accountNumber: "****9012", ifsc: "ICIC0003333", accountHolderName: "Vikram Singh" }], upiIds: ["vikram@icici"], avatar: "", createdAt: "2024-03-01T10:00:00Z" },
  { id: "c5", name: "Anita Desai", phone: "+91 55443 32211", email: "anita.d@email.com", bankDetails: [{ bankName: "Axis Bank", accountNumber: "****3456", ifsc: "UTIB0004444", accountHolderName: "Anita Desai" }], upiIds: ["anita@axisbank"], avatar: "", createdAt: "2024-03-15T10:00:00Z" },
  { id: "c6", name: "Karan Joshi", phone: "+91 44332 21100", whatsappNumber: "+91 44332 21100", bankDetails: [], upiIds: ["karan@paytm"], avatar: "", createdAt: "2024-04-01T10:00:00Z" },
  { id: "c7", name: "Meera Nair", phone: "+91 33221 10099", email: "meera.n@email.com", bankDetails: [{ bankName: "Kotak Mahindra", accountNumber: "****7890", ifsc: "KKBK0005555", accountHolderName: "Meera Nair" }], upiIds: ["meera@kotak"], avatar: "", createdAt: "2024-04-10T10:00:00Z" },
  { id: "c8", name: "Amit Kumar", phone: "+91 22110 09988", whatsappNumber: "+91 22110 09988", email: "amit.k@email.com", bankDetails: [], upiIds: ["amit@okicici"], avatar: "", createdAt: "2024-05-01T10:00:00Z" },
];

// --- Transactions ---
export const mockTransactions: Transaction[] = [
  { id: "t1", type: "expense", amount: 4520, currency: "INR", category: "groceries", description: "BigBasket Weekly Groceries", date: "2026-02-19T10:30:00Z", paymentMethodId: "pm1", paymentMethodName: "UPI", paymentMethodType: "upi", paymentSourceId: "ps5", paymentSourceName: "Google Pay", notes: "Weekly grocery order", cashback: 45, cashbackSource: "Google Pay", createdAt: "2026-02-19T10:30:00Z", updatedAt: "2026-02-19T10:30:00Z" },
  { id: "t2", type: "expense", amount: 1250, currency: "INR", category: "food_dining", description: "Dinner at Barbeque Nation", date: "2026-02-18T20:00:00Z", paymentMethodId: "pm2", paymentMethodName: "Credit Card", paymentMethodType: "credit_card", paymentSourceId: "ps3", paymentSourceName: "ICICI Credit Card", notes: "Team dinner", cashback: 62, cashbackSource: "ICICI", createdAt: "2026-02-18T20:00:00Z", updatedAt: "2026-02-18T20:00:00Z" },
  { id: "t3", type: "income", amount: 85000, currency: "INR", category: "salary", description: "Monthly Salary - February", date: "2026-02-01T09:00:00Z", paymentMethodId: "pm5", paymentMethodName: "Bank Transfer", paymentMethodType: "bank_transfer", paymentSourceId: "ps2", paymentSourceName: "SBI Salary Account", createdAt: "2026-02-01T09:00:00Z", updatedAt: "2026-02-01T09:00:00Z" },
  { id: "t4", type: "expense", amount: 15000, currency: "INR", category: "rent", description: "House Rent - February", date: "2026-02-05T10:00:00Z", paymentMethodId: "pm5", paymentMethodName: "Bank Transfer", paymentMethodType: "bank_transfer", paymentSourceId: "ps1", paymentSourceName: "HDFC Bank Savings", createdAt: "2026-02-05T10:00:00Z", updatedAt: "2026-02-05T10:00:00Z" },
  { id: "t5", type: "expense", amount: 2100, currency: "INR", category: "utilities", description: "Electricity Bill - BESCOM", date: "2026-02-10T11:00:00Z", paymentMethodId: "pm1", paymentMethodName: "UPI", paymentMethodType: "upi", paymentSourceId: "ps6", paymentSourceName: "PhonePe", cashback: 21, cashbackSource: "PhonePe", createdAt: "2026-02-10T11:00:00Z", updatedAt: "2026-02-10T11:00:00Z" },
  { id: "t6", type: "expense", amount: 799, currency: "INR", category: "subscriptions", description: "Netflix Monthly Subscription", date: "2026-02-08T00:00:00Z", paymentMethodId: "pm2", paymentMethodName: "Credit Card", paymentMethodType: "credit_card", paymentSourceId: "ps4", paymentSourceName: "Axis Bank Credit Card", createdAt: "2026-02-08T00:00:00Z", updatedAt: "2026-02-08T00:00:00Z" },
  { id: "t7", type: "expense", amount: 350, currency: "INR", category: "transport", description: "Uber Ride to Airport", date: "2026-02-17T06:00:00Z", paymentMethodId: "pm1", paymentMethodName: "UPI", paymentMethodType: "upi", paymentSourceId: "ps5", paymentSourceName: "Google Pay", createdAt: "2026-02-17T06:00:00Z", updatedAt: "2026-02-17T06:00:00Z" },
  { id: "t8", type: "income", amount: 25000, currency: "INR", category: "freelance", description: "Website Design Project - Client ABC", date: "2026-02-12T14:00:00Z", paymentMethodId: "pm5", paymentMethodName: "Bank Transfer", paymentMethodType: "bank_transfer", paymentSourceId: "ps1", paymentSourceName: "HDFC Bank Savings", createdAt: "2026-02-12T14:00:00Z", updatedAt: "2026-02-12T14:00:00Z" },
  { id: "t9", type: "expense", amount: 3200, currency: "INR", category: "shopping", description: "Amazon - Wireless Headphones", date: "2026-02-15T16:00:00Z", paymentMethodId: "pm2", paymentMethodName: "Credit Card", paymentMethodType: "credit_card", paymentSourceId: "ps3", paymentSourceName: "ICICI Credit Card", cashback: 160, cashbackSource: "Amazon Pay ICICI", createdAt: "2026-02-15T16:00:00Z", updatedAt: "2026-02-15T16:00:00Z" },
  { id: "t10", type: "expense", amount: 500, currency: "INR", category: "health", description: "Apollo Pharmacy - Medicines", date: "2026-02-16T09:00:00Z", paymentMethodId: "pm1", paymentMethodName: "UPI", paymentMethodType: "upi", paymentSourceId: "ps7", paymentSourceName: "Paytm", cashback: 25, cashbackSource: "Paytm", createdAt: "2026-02-16T09:00:00Z", updatedAt: "2026-02-16T09:00:00Z" },
  { id: "t11", type: "expense", amount: 5000, currency: "INR", category: "entertainment", description: "Weekend Trip - Entry Tickets", date: "2026-02-14T10:00:00Z", paymentMethodId: "pm4", paymentMethodName: "Cash", paymentMethodType: "cash", paymentSourceId: "ps1", paymentSourceName: "HDFC Bank Savings", createdAt: "2026-02-14T10:00:00Z", updatedAt: "2026-02-14T10:00:00Z" },
  { id: "t12", type: "expense", amount: 2000, currency: "INR", category: "food_dining", description: "Swiggy Orders (Weekly)", date: "2026-02-13T20:00:00Z", paymentMethodId: "pm1", paymentMethodName: "UPI", paymentMethodType: "upi", paymentSourceId: "ps6", paymentSourceName: "PhonePe", cashback: 40, cashbackSource: "PhonePe", createdAt: "2026-02-13T20:00:00Z", updatedAt: "2026-02-13T20:00:00Z" },
  { id: "t13", type: "expense", amount: 10000, currency: "INR", category: "atm", description: "ATM Cash Withdrawal", date: "2026-02-11T12:00:00Z", paymentMethodId: "pm6", paymentMethodName: "ATM Withdrawal", paymentMethodType: "atm", paymentSourceId: "ps1", paymentSourceName: "HDFC Bank Savings", createdAt: "2026-02-11T12:00:00Z", updatedAt: "2026-02-11T12:00:00Z" },
  { id: "t14", type: "income", amount: 5000, currency: "INR", category: "investment_returns", description: "Mutual Fund Dividend - SBI Bluechip", date: "2026-02-07T10:00:00Z", paymentMethodId: "pm5", paymentMethodName: "Bank Transfer", paymentMethodType: "bank_transfer", paymentSourceId: "ps2", paymentSourceName: "SBI Salary Account", createdAt: "2026-02-07T10:00:00Z", updatedAt: "2026-02-07T10:00:00Z" },
  { id: "t15", type: "expense", amount: 1800, currency: "INR", category: "personal_care", description: "Salon - Haircut & Grooming", date: "2026-02-09T11:00:00Z", paymentMethodId: "pm1", paymentMethodName: "UPI", paymentMethodType: "upi", paymentSourceId: "ps5", paymentSourceName: "Google Pay", createdAt: "2026-02-09T11:00:00Z", updatedAt: "2026-02-09T11:00:00Z" },
  { id: "t16", type: "expense", amount: 12500, currency: "INR", category: "insurance", description: "Health Insurance Premium - HDFC Ergo", date: "2026-02-03T10:00:00Z", paymentMethodId: "pm7", paymentMethodName: "Net Banking", paymentMethodType: "net_banking", paymentSourceId: "ps1", paymentSourceName: "HDFC Bank Savings", createdAt: "2026-02-03T10:00:00Z", updatedAt: "2026-02-03T10:00:00Z" },
  { id: "t17", type: "income", amount: 3000, currency: "INR", category: "refund", description: "Flipkart Return Refund", date: "2026-02-06T15:00:00Z", paymentMethodId: "pm5", paymentMethodName: "Bank Transfer", paymentMethodType: "bank_transfer", paymentSourceId: "ps3", paymentSourceName: "ICICI Credit Card", createdAt: "2026-02-06T15:00:00Z", updatedAt: "2026-02-06T15:00:00Z" },
  { id: "t18", type: "expense", amount: 450, currency: "INR", category: "transport", description: "Metro Card Recharge", date: "2026-02-04T08:00:00Z", paymentMethodId: "pm1", paymentMethodName: "UPI", paymentMethodType: "upi", paymentSourceId: "ps7", paymentSourceName: "Paytm", createdAt: "2026-02-04T08:00:00Z", updatedAt: "2026-02-04T08:00:00Z" },
  { id: "t19", type: "expense", amount: 6500, currency: "INR", category: "education", description: "Udemy Course - React Advanced", date: "2026-02-02T10:00:00Z", paymentMethodId: "pm2", paymentMethodName: "Credit Card", paymentMethodType: "credit_card", paymentSourceId: "ps4", paymentSourceName: "Axis Bank Credit Card", cashback: 325, cashbackSource: "Axis Bank", createdAt: "2026-02-02T10:00:00Z", updatedAt: "2026-02-02T10:00:00Z" },
  { id: "t20", type: "expense", amount: 850, currency: "INR", category: "food_dining", description: "Chai Point & Snacks", date: "2026-02-19T15:00:00Z", paymentMethodId: "pm4", paymentMethodName: "Cash", paymentMethodType: "cash", paymentSourceId: "ps1", paymentSourceName: "HDFC Bank Savings", createdAt: "2026-02-19T15:00:00Z", updatedAt: "2026-02-19T15:00:00Z" },
  // January transactions for trend data
  { id: "t21", type: "income", amount: 85000, currency: "INR", category: "salary", description: "Monthly Salary - January", date: "2026-01-01T09:00:00Z", paymentMethodId: "pm5", paymentMethodName: "Bank Transfer", paymentMethodType: "bank_transfer", paymentSourceId: "ps2", paymentSourceName: "SBI Salary Account", createdAt: "2026-01-01T09:00:00Z", updatedAt: "2026-01-01T09:00:00Z" },
  { id: "t22", type: "expense", amount: 15000, currency: "INR", category: "rent", description: "House Rent - January", date: "2026-01-05T10:00:00Z", paymentMethodId: "pm5", paymentMethodName: "Bank Transfer", paymentMethodType: "bank_transfer", paymentSourceId: "ps1", paymentSourceName: "HDFC Bank Savings", createdAt: "2026-01-05T10:00:00Z", updatedAt: "2026-01-05T10:00:00Z" },
  { id: "t23", type: "expense", amount: 8500, currency: "INR", category: "shopping", description: "Myntra - Winter Clothing", date: "2026-01-10T14:00:00Z", paymentMethodId: "pm2", paymentMethodName: "Credit Card", paymentMethodType: "credit_card", paymentSourceId: "ps3", paymentSourceName: "ICICI Credit Card", cashback: 425, cashbackSource: "ICICI", createdAt: "2026-01-10T14:00:00Z", updatedAt: "2026-01-10T14:00:00Z" },
  { id: "t24", type: "expense", amount: 3500, currency: "INR", category: "groceries", description: "Zepto Groceries", date: "2026-01-15T11:00:00Z", paymentMethodId: "pm1", paymentMethodName: "UPI", paymentMethodType: "upi", paymentSourceId: "ps6", paymentSourceName: "PhonePe", cashback: 35, cashbackSource: "PhonePe", createdAt: "2026-01-15T11:00:00Z", updatedAt: "2026-01-15T11:00:00Z" },
  { id: "t25", type: "income", amount: 15000, currency: "INR", category: "freelance", description: "Logo Design - Client XYZ", date: "2026-01-20T14:00:00Z", paymentMethodId: "pm1", paymentMethodName: "UPI", paymentMethodType: "upi", paymentSourceId: "ps5", paymentSourceName: "Google Pay", createdAt: "2026-01-20T14:00:00Z", updatedAt: "2026-01-20T14:00:00Z" },
];

// --- Split Bills ---
export const mockSplitBills: SplitBill[] = [
  {
    id: "sb1", title: "Weekend Trip to Goa", description: "Hotel + food + travel", totalAmount: 24000, splitType: "equal",
    participants: [
      { contactId: "u1", contactName: "Arjun Mehta (You)", amount: 6000, isPaid: true, paidDate: "2026-02-14T10:00:00Z" },
      { contactId: "c1", contactName: "Priya Sharma", amount: 6000, isPaid: true, paidDate: "2026-02-15T10:00:00Z" },
      { contactId: "c2", contactName: "Rahul Verma", amount: 6000, isPaid: false },
      { contactId: "c4", contactName: "Vikram Singh", amount: 6000, isPaid: false },
    ],
    createdBy: "u1", date: "2026-02-14T10:00:00Z", isSettled: false, createdAt: "2026-02-14T10:00:00Z",
  },
  {
    id: "sb2", title: "Team Lunch at Office", totalAmount: 3500, splitType: "equal",
    participants: [
      { contactId: "u1", contactName: "Arjun Mehta (You)", amount: 700, isPaid: true, paidDate: "2026-02-10T13:00:00Z" },
      { contactId: "c3", contactName: "Sneha Patel", amount: 700, isPaid: true, paidDate: "2026-02-10T14:00:00Z" },
      { contactId: "c5", contactName: "Anita Desai", amount: 700, isPaid: true, paidDate: "2026-02-11T10:00:00Z" },
      { contactId: "c6", contactName: "Karan Joshi", amount: 700, isPaid: false },
      { contactId: "c7", contactName: "Meera Nair", amount: 700, isPaid: true, paidDate: "2026-02-11T12:00:00Z" },
    ],
    createdBy: "u1", date: "2026-02-10T13:00:00Z", isSettled: false, createdAt: "2026-02-10T13:00:00Z",
  },
  {
    id: "sb3", title: "Birthday Gift for Vikram", totalAmount: 5000, splitType: "custom",
    participants: [
      { contactId: "u1", contactName: "Arjun Mehta (You)", amount: 2000, isPaid: true, paidDate: "2026-02-01T10:00:00Z" },
      { contactId: "c1", contactName: "Priya Sharma", amount: 1500, isPaid: true, paidDate: "2026-02-01T12:00:00Z" },
      { contactId: "c2", contactName: "Rahul Verma", amount: 1500, isPaid: true, paidDate: "2026-02-02T10:00:00Z" },
    ],
    createdBy: "u1", date: "2026-02-01T10:00:00Z", isSettled: true, createdAt: "2026-02-01T10:00:00Z",
  },
];

// --- Share Groups ---
export const mockShareGroups: ShareGroup[] = [
  {
    id: "sg1", name: "Flatmates", description: "Monthly shared expenses for flat",
    members: [
      { contactId: "u1", contactName: "Arjun Mehta (You)", balance: 2500 },
      { contactId: "c2", contactName: "Rahul Verma", balance: -1200 },
      { contactId: "c4", contactName: "Vikram Singh", balance: -1300 },
    ],
    bills: ["sb1"], createdBy: "u1", createdAt: "2024-06-01T10:00:00Z",
  },
  {
    id: "sg2", name: "Office Gang", description: "Work lunches and outings",
    members: [
      { contactId: "u1", contactName: "Arjun Mehta (You)", balance: 700 },
      { contactId: "c3", contactName: "Sneha Patel", balance: 0 },
      { contactId: "c5", contactName: "Anita Desai", balance: 0 },
      { contactId: "c6", contactName: "Karan Joshi", balance: -700 },
      { contactId: "c7", contactName: "Meera Nair", balance: 0 },
    ],
    bills: ["sb2"], createdBy: "u1", createdAt: "2024-08-15T10:00:00Z",
  },
  {
    id: "sg3", name: "College Friends", description: "Trips and hangouts",
    members: [
      { contactId: "u1", contactName: "Arjun Mehta (You)", balance: 0 },
      { contactId: "c1", contactName: "Priya Sharma", balance: 0 },
      { contactId: "c8", contactName: "Amit Kumar", balance: 0 },
    ],
    bills: ["sb3"], createdBy: "u1", createdAt: "2024-03-10T10:00:00Z",
  },
];

// --- Notifications ---
export const mockNotifications: Notification[] = [
  { id: "n1", type: "credit_card_due", title: "ICICI Credit Card Due", message: "Your ICICI credit card payment of Rs. 18,450 is due on 25th February.", isRead: false, dueDate: "2026-02-25T00:00:00Z", relatedEntityId: "ps3", relatedEntityType: "payment_source", createdAt: "2026-02-20T08:00:00Z" },
  { id: "n2", type: "bill_due", title: "Electricity Bill Due", message: "BESCOM electricity bill of Rs. 2,100 is due in 3 days.", isRead: false, dueDate: "2026-02-23T00:00:00Z", createdAt: "2026-02-20T08:00:00Z" },
  { id: "n3", type: "split_settlement", title: "Payment Pending from Rahul", message: "Rahul Verma owes you Rs. 6,000 for the Goa trip.", isRead: false, relatedEntityId: "sb1", relatedEntityType: "split_bill", createdAt: "2026-02-19T10:00:00Z" },
  { id: "n4", type: "cashback_received", title: "Cashback Credited", message: "Rs. 45 cashback from Google Pay has been credited for your BigBasket order.", isRead: true, relatedEntityId: "t1", relatedEntityType: "transaction", createdAt: "2026-02-19T11:00:00Z" },
  { id: "n5", type: "bill_due", title: "Netflix Subscription Due", message: "Your Netflix subscription of Rs. 799 will be auto-debited on 8th March.", isRead: true, dueDate: "2026-03-08T00:00:00Z", createdAt: "2026-02-18T08:00:00Z" },
  { id: "n6", type: "credit_card_due", title: "Axis Bank Credit Card Due", message: "Your Axis Bank credit card minimum payment of Rs. 3,500 is due on 1st March.", isRead: true, dueDate: "2026-03-01T00:00:00Z", relatedEntityId: "ps4", relatedEntityType: "payment_source", createdAt: "2026-02-18T08:00:00Z" },
  { id: "n7", type: "payment_reminder", title: "Rent Due Soon", message: "Monthly house rent of Rs. 15,000 is due on 5th March.", isRead: true, dueDate: "2026-03-05T00:00:00Z", createdAt: "2026-02-17T08:00:00Z" },
  { id: "n8", type: "split_settlement", title: "Payment Received from Priya", message: "Priya Sharma paid Rs. 6,000 for the Goa trip split.", isRead: true, relatedEntityId: "sb1", relatedEntityType: "split_bill", createdAt: "2026-02-15T10:00:00Z" },
  { id: "n9", type: "system", title: "Welcome to FinTrack", message: "Start tracking your finances by adding your first transaction.", isRead: true, createdAt: "2024-01-15T10:00:00Z" },
];

// --- Analytics Data ---
export const mockAnalyticsOverview: AnalyticsOverview = {
  totalIncome: 118000,
  totalExpenses: 86819,
  netSavings: 31181,
  totalCashback: 1138,
  transactionCount: 25,
  avgTransactionAmount: 8193,
  topCategory: "rent",
  topPaymentMethod: "upi",
};

export const mockMethodBreakdowns: MethodBreakdown[] = [
  { method: "upi", label: "UPI", totalAmount: 12270, transactionCount: 8, percentage: 26, sources: [{ sourceId: "ps5", sourceName: "Google Pay", totalAmount: 6670, transactionCount: 3, percentage: 54 }, { sourceId: "ps6", sourceName: "PhonePe", totalAmount: 5600, transactionCount: 3, percentage: 32 }, { sourceId: "ps7", sourceName: "Paytm", totalAmount: 950, transactionCount: 2, percentage: 14 }] },
  { method: "credit_card", label: "Credit Card", totalAmount: 22949, transactionCount: 5, percentage: 35, sources: [{ sourceId: "ps3", sourceName: "ICICI Credit Card", totalAmount: 12950, transactionCount: 3, percentage: 56 }, { sourceId: "ps4", sourceName: "Axis Bank Credit Card", totalAmount: 7299, transactionCount: 2, percentage: 44 }] },
  { method: "bank_transfer", label: "Bank Transfer", totalAmount: 30000, transactionCount: 3, percentage: 22, sources: [{ sourceId: "ps1", sourceName: "HDFC Bank Savings", totalAmount: 15000, transactionCount: 1, percentage: 50 }, { sourceId: "ps2", sourceName: "SBI Salary Account", totalAmount: 15000, transactionCount: 2, percentage: 50 }] },
  { method: "cash", label: "Cash", totalAmount: 5850, transactionCount: 2, percentage: 10, sources: [{ sourceId: "ps1", sourceName: "HDFC Bank Savings", totalAmount: 5850, transactionCount: 2, percentage: 100 }] },
  { method: "atm", label: "ATM", totalAmount: 10000, transactionCount: 1, percentage: 5, sources: [{ sourceId: "ps1", sourceName: "HDFC Bank Savings", totalAmount: 10000, transactionCount: 1, percentage: 100 }] },
  { method: "net_banking", label: "Net Banking", totalAmount: 12500, transactionCount: 1, percentage: 2, sources: [{ sourceId: "ps1", sourceName: "HDFC Bank Savings", totalAmount: 12500, transactionCount: 1, percentage: 100 }] },
];

export const mockCategoryBreakdowns: CategoryBreakdown[] = [
  { category: "rent", label: "Rent", totalAmount: 30000, transactionCount: 2, percentage: 25, color: "#0ea5e9" },
  { category: "groceries", label: "Groceries", totalAmount: 8020, transactionCount: 2, percentage: 10, color: "#22c55e" },
  { category: "food_dining", label: "Food & Dining", totalAmount: 4100, transactionCount: 3, percentage: 8, color: "#f97316" },
  { category: "shopping", label: "Shopping", totalAmount: 11700, transactionCount: 2, percentage: 14, color: "#a855f7" },
  { category: "insurance", label: "Insurance", totalAmount: 12500, transactionCount: 1, percentage: 10, color: "#ef4444" },
  { category: "utilities", label: "Utilities", totalAmount: 2100, transactionCount: 1, percentage: 4, color: "#eab308" },
  { category: "transport", label: "Transport", totalAmount: 800, transactionCount: 2, percentage: 2, color: "#06b6d4" },
  { category: "subscriptions", label: "Subscriptions", totalAmount: 799, transactionCount: 1, percentage: 1, color: "#ec4899" },
  { category: "entertainment", label: "Entertainment", totalAmount: 5000, transactionCount: 1, percentage: 8, color: "#8b5cf6" },
  { category: "health", label: "Health", totalAmount: 500, transactionCount: 1, percentage: 1, color: "#14b8a6" },
  { category: "education", label: "Education", totalAmount: 6500, transactionCount: 1, percentage: 8, color: "#3b82f6" },
  { category: "personal_care", label: "Personal Care", totalAmount: 1800, transactionCount: 1, percentage: 3, color: "#f43f5e" },
];

export const mockCashbackAnalytics: CashbackAnalytics = {
  totalCashback: 1138,
  byMethod: [
    { method: "Credit Card", amount: 972, percentage: 54 },
    { method: "UPI", amount: 166, percentage: 46 },
  ],
  bySource: [
    { source: "ICICI Credit Card", amount: 487, percentage: 27 },
    { source: "Axis Bank Credit Card", amount: 325, percentage: 18 },
    { source: "Amazon Pay ICICI", amount: 160, percentage: 9 },
    { source: "Google Pay", amount: 45, percentage: 15 },
    { source: "PhonePe", amount: 96, percentage: 21 },
    { source: "Paytm", amount: 25, percentage: 10 },
  ],
  bestMethod: "Credit Card",
  bestSource: "ICICI Credit Card",
};

export const mockTrendData: TrendDataPoint[] = [
  { period: "Sep 2025", income: 90000, expenses: 62000, savings: 28000, cashback: 450 },
  { period: "Oct 2025", income: 95000, expenses: 71000, savings: 24000, cashback: 680 },
  { period: "Nov 2025", income: 88000, expenses: 58000, savings: 30000, cashback: 520 },
  { period: "Dec 2025", income: 110000, expenses: 92000, savings: 18000, cashback: 1200 },
  { period: "Jan 2026", income: 100000, expenses: 75000, savings: 25000, cashback: 890 },
  { period: "Feb 2026", income: 118000, expenses: 86819, savings: 31181, cashback: 1138 },
];

export const mockSmartSuggestions: SmartSuggestion[] = [
  { id: "ss1", type: "best_method", title: "Best Payment Method", description: "Credit Cards give you the highest cashback at 5.4% average return on your spending.", metric: "Avg. Cashback Rate", metricValue: "5.4%" },
  { id: "ss2", type: "best_source", title: "Top Cashback Source", description: "ICICI Credit Card has earned you the most cashback this month. Consider using it for high-value purchases.", metric: "Total Cashback", metricValue: "Rs. 487" },
  { id: "ss3", type: "best_app", title: "Recommended UPI App", description: "Google Pay offers the best UPI cashback deals. Use it for daily UPI payments.", metric: "UPI Cashback", metricValue: "Rs. 45" },
  { id: "ss4", type: "savings_tip", title: "Savings Opportunity", description: "Your Food & Dining expenses are 8% of total. Consider meal prepping to reduce this by 30%.", metric: "Potential Saving", metricValue: "Rs. 1,230/mo" },
];

export const mockPeriodComparison: PeriodComparison = {
  currentPeriod: { label: "February 2026", income: 118000, expenses: 86819, savings: 31181 },
  previousPeriod: { label: "January 2026", income: 100000, expenses: 75000, savings: 25000 },
  incomeChange: 18,
  expenseChange: 15.76,
  savingsChange: 24.72,
};
