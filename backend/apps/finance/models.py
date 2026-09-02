from django.db import models
from django.conf import settings


class SourceType(models.Model):
    """
    Payment source type (Bank Account, Credit Card, etc.). Built-in types are
    created by migration; admins can add more via Django admin.
    """
    key = models.CharField(max_length=20, unique=True, help_text="e.g. BANK, CREDIT_CARD")
    label = models.CharField(max_length=100, help_text="Display name e.g. Bank Account")
    is_builtin = models.BooleanField(
        default=False,
        help_text="Built-in types are created by migration; prevent accidental deletion.",
    )

    class Meta:
        ordering = ["key"]
        verbose_name = "Payment source type"
        verbose_name_plural = "Payment source types"

    def __str__(self):
        return f"{self.label} ({self.key})"


class PaymentApp(models.Model):
    """
    Apps like Google Pay, Apple Pay, PhonePe, PayTM, CRED, or specific Bank Apps.
    Each app supports a subset of payment methods (UPI, wallet, cards, etc.).
    Sources are linked to apps (and optionally to a method within the app) via PaymentAppSource.
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="payment_apps")
    name = models.CharField(max_length=100)  # e.g., "Google Pay", "HDFC Bank"
    # List of method keys (from built-in PaymentMethod.key) this app supports, e.g. ["UPI", "WALLET"]
    supported_methods = models.JSONField(default=list, help_text="e.g. [\"UPI\", \"WALLET\"]")
    # List of PaymentMethod ids (so custom methods like NEFT vs Bank Transfer are distinct)
    supported_method_ids = models.JSONField(default=list, help_text="e.g. [1, 9, 11]")
    is_active = models.BooleanField(default=True)
    icon = models.ImageField(upload_to="apps/icons/", null=True, blank=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class PaymentAppSource(models.Model):
    """
    Links a payment source to a payment app for a specific method.
    A source can be linked to multiple apps; an app can have many sources per method.
    """
    payment_app = models.ForeignKey(
        PaymentApp,
        on_delete=models.CASCADE,
        related_name="source_links",
        help_text="App this source is linked to.",
    )
    payment_method = models.ForeignKey(
        "PaymentMethod",
        on_delete=models.CASCADE,
        related_name="app_source_links",
        help_text="Method within the app that can use this source.",
    )
    payment_source = models.ForeignKey(
        "PaymentSource",
        on_delete=models.CASCADE,
        related_name="app_links",
        help_text="Payment source linked to the app for this method.",
    )

    class Meta:
        ordering = ["payment_app", "payment_method", "payment_source"]
        unique_together = [("payment_app", "payment_method", "payment_source")]
        verbose_name = "App–source link"
        verbose_name_plural = "App–source links"

    def __str__(self):
        return f"{self.payment_app.name} / {self.payment_method} ← {self.payment_source.name}"


class PaymentSource(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="payment_sources")
    # Linked to apps via PaymentAppSource (many-to-many: a source can be in multiple apps)
    # For DEBIT_CARD (required) and CREDIT_CARD (optional): the bank account this card is linked to (expenses/repayments).
    linked_bank_source = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="card_sources",
        help_text="Bank account linked to this card. Required for debit cards; optional for credit cards.",
    )
    name = models.CharField(max_length=100)  # e.g., "HDFC Salary Account" or "Amex Gold"
    bank_name = models.CharField(max_length=100, blank=True)
    source_type = models.ForeignKey(
        SourceType,
        on_delete=models.PROTECT,
        related_name="payment_sources",
        help_text="Type of payment source (bank, card, wallet, etc.). Managed in Payment source types.",
    )
    balance = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return f"{self.name} ({self.user.username})"


class PaymentMethod(models.Model):
    """
    Payment method (e.g. UPI, Card, NEFT). Can be built-in (user=null) or custom (user set).
    Each method has one or more allowed source types (multi-select); at least one required.
    """
    # Optional key for built-in methods (e.g. UPI, CASH); custom methods usually have key=null
    key = models.CharField(max_length=20, unique=True, null=True, blank=True)
    name = models.CharField(max_length=100, blank=True, help_text="Display name (e.g. UPI Payment, NEFT)")
    # Which source types this method allows (required, at least one)
    source_types = models.ManyToManyField(
        SourceType,
        related_name="payment_methods",
        blank=True,
        help_text="Select one or more payment source types allowed for this method. At least one required.",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="payment_methods",
        help_text="Null = built-in method; set = user's custom method.",
    )

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name or (self.key or str(self.id))


# TypeError: Transaction() got unexpected keyword arguments: 'payment_app_name', 'notes'
class Transaction(models.Model):
    TRANSACTION_TYPES = (('INCOME', 'Income'), ('EXPENSE', 'Expense'))
    METHODS = (
        ('UPI', 'UPI Payment'),
        ('CASH', 'Cash'),
        ('ATM', 'ATM Withdrawal'),
        ('CREDIT_CARD', 'Credit Card'),
        ('DEBIT_CARD', 'Debit Card'),
        ('WALLET', 'Wallet'),
        ('NET_BANKING', 'Net Banking'),
        ('CHECK', 'Check'),
        ('TRANSFER', 'Bank Transfer'),
        ('OTHER', 'Other'),
    )

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)

    payment_app_id = models.ForeignKey(PaymentApp, on_delete=models.SET_NULL, null=True, blank=True, related_name='transactions')
    payment_method_id = models.ForeignKey(PaymentMethod, on_delete=models.SET_NULL, null=True, blank=True)
    payment_source_id = models.ForeignKey(
        PaymentSource, on_delete=models.PROTECT, related_name='transactions'
    )
    
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    type = models.CharField(max_length=10, choices=TRANSACTION_TYPES)
    category = models.CharField(max_length=100) # e.g., Food, Rent, Salary
    
    description = models.TextField(blank=True)
    # cashback is only applicable for expenses
    cashback_received = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    
    # For OCR/Image Scanning tracking
    is_automated = models.BooleanField(default=False)
    receipt_image = models.ImageField(upload_to='receipts/', null=True, blank=True)
    
    timestamp = models.DateTimeField(auto_now_add=True)

    notes = models.TextField(blank=True)

    def __str__(self):
        pm = self.payment_method_id
        method_label = (pm.name if pm else None) or (getattr(pm, "key", None) if pm else None) or "Unknown"
        return f"{self.type}: {self.amount} via {method_label}"


class Cashback(models.Model):
    """
    Cashback received on an expense. Stored in a separate table linked to transaction_id.
    Types: fixed amount, percentage of expense, or reward points (to app used for expense).
    Fixed/percentage can be credited to same or different payment source; creates an INCOME transaction.
    """
    KIND_FIXED = "fixed"
    KIND_PERCENTAGE = "percentage"
    KIND_REWARD_POINTS = "reward_points"
    KIND_CHOICES = [
        (KIND_FIXED, "Fixed amount"),
        (KIND_PERCENTAGE, "Percentage of expense"),
        (KIND_REWARD_POINTS, "Reward points (app)"),
    ]

    transaction = models.ForeignKey(
        Transaction,
        on_delete=models.CASCADE,
        related_name="cashback_records",
        help_text="Expense transaction this cashback is for.",
    )
    kind = models.CharField(max_length=20, choices=KIND_CHOICES, default=KIND_FIXED)
    # For fixed: amount in currency. For percentage: amount = expense.amount * percentage / 100 (stored after compute).
    amount = models.DecimalField(max_digits=12, decimal_places=2, default=0.00)
    # Only for kind=percentage: stored percentage (e.g. 5.00 for 5%)
    percentage = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    # Only for kind=reward_points
    reward_points = models.PositiveIntegerField(null=True, blank=True)
    # App used for expense (for reward_points) or optional display
    reward_app = models.ForeignKey(
        PaymentApp,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="cashback_rewards",
    )
    # Where cashback is credited (same or different source). Null for reward_points.
    credit_source = models.ForeignKey(
        PaymentSource,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="cashback_credits",
    )
    # The INCOME transaction created when crediting to a source (fixed/percentage only)
    income_transaction = models.ForeignKey(
        Transaction,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="source_cashback",
    )

    class Meta:
        verbose_name = "Cashback"
        verbose_name_plural = "Cashbacks"

    def __str__(self):
        return f"Cashback {self.amount} on txn #{self.transaction_id} ({self.get_kind_display()})"