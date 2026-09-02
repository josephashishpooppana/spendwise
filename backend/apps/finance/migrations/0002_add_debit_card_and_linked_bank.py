# Generated manually for DEBIT_CARD and linked_bank_source

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0001_initial"),
    ]

    operations = [
        migrations.AlterField(
            model_name="paymentsource",
            name="source_type",
            field=models.CharField(
                choices=[
                    ("BANK", "Bank Account"),
                    ("CREDIT_CARD", "Credit Card"),
                    ("DEBIT_CARD", "Debit Card"),
                    ("WALLET", "Digital Wallet"),
                    ("CASH", "Physical Cash"),
                ],
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="paymentsource",
            name="linked_bank_source",
            field=models.ForeignKey(
                blank=True,
                help_text="Bank account linked to this card. Required for debit cards; optional for credit cards.",
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="card_sources",
                to="finance.paymentsource",
            ),
        ),
    ]
