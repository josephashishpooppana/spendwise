# Create built-in PaymentMethod rows with key, name, and source_types (no hardcoded METHOD_KEYS in code)

from django.db import migrations


BUILTIN_METHODS = [
    ("UPI", "UPI Payment", ["CREDIT_CARD", "DEBIT_CARD"]),
    ("CASH", "Cash", ["CASH"]),
    ("ATM", "ATM Withdrawal", ["BANK"]),
    ("CREDIT_CARD", "Credit Card", ["CREDIT_CARD"]),
    ("DEBIT_CARD", "Debit Card", ["DEBIT_CARD"]),
    ("WALLET", "Wallet", ["WALLET"]),
    ("NET_BANKING", "Net Banking", ["BANK"]),
    ("CHECK", "Check", ["BANK"]),
    ("TRANSFER", "Bank Transfer", ["BANK"]),
    ("OTHER", "Other", ["BANK", "CREDIT_CARD", "DEBIT_CARD", "WALLET", "CASH"]),
]


def create_builtin_payment_methods(apps, schema_editor):
    PaymentMethod = apps.get_model("finance", "PaymentMethod")
    SourceType = apps.get_model("finance", "SourceType")
    key_to_id = dict(SourceType.objects.values_list("key", "id"))
    for key, name, source_keys in BUILTIN_METHODS:
        pm, _ = PaymentMethod.objects.get_or_create(
            key=key,
            user=None,
            defaults={"name": name},
        )
        st_ids = [key_to_id[k] for k in source_keys if k in key_to_id]
        if st_ids:
            pm.source_types.set(st_ids)


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0013_paymentmethod_source_types_m2m"),
    ]

    operations = [
        migrations.RunPython(create_builtin_payment_methods, noop),
    ]
