# Generated manually

from django.db import migrations, models


def create_source_types(apps, schema_editor):
    SourceType = apps.get_model("finance", "SourceType")
    for key, label in [
        ("BANK", "Bank Account"),
        ("CREDIT_CARD", "Credit Card"),
        ("DEBIT_CARD", "Debit Card"),
        ("WALLET", "Digital Wallet"),
        ("CASH", "Physical Cash"),
    ]:
        SourceType.objects.get_or_create(key=key, defaults={"label": label})


def backfill_allowed_source_types(apps, schema_editor):
    PaymentMethod = apps.get_model("finance", "PaymentMethod")
    METHOD_TO_SOURCE_TYPES = {
        "UPI": ["CREDIT_CARD", "DEBIT_CARD"],
        "CREDIT_CARD": ["CREDIT_CARD"],
        "DEBIT_CARD": ["DEBIT_CARD"],
        "WALLET": ["WALLET"],
        "NET_BANKING": ["BANK"],
        "CASH": ["CASH"],
        "ATM": ["BANK"],
        "TRANSFER": ["BANK"],
        "CHECK": ["BANK"],
        "OTHER": ["BANK", "CREDIT_CARD", "DEBIT_CARD", "WALLET", "CASH"],
    }
    for pm in PaymentMethod.objects.all():
        if not pm.allowed_source_types:
            pm.allowed_source_types = METHOD_TO_SOURCE_TYPES.get(pm.key, [])
            pm.save(update_fields=["allowed_source_types"])


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0008_add_supported_method_ids"),
    ]

    operations = [
        migrations.CreateModel(
            name="SourceType",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("key", models.CharField(max_length=20, unique=True)),
                ("label", models.CharField(max_length=100)),
            ],
            options={
                "ordering": ["key"],
            },
        ),
        migrations.AddField(
            model_name="paymentmethod",
            name="allowed_source_types",
            field=models.JSONField(blank=True, default=list, help_text='List of source type keys, e.g. ["BANK"]'),
        ),
        migrations.RunPython(create_source_types, noop),
        migrations.RunPython(backfill_allowed_source_types, noop),
    ]
