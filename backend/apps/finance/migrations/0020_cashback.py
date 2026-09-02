# Cashback model: separate table linked to transaction_id

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0019_transaction_payment_source_required"),
    ]

    operations = [
        migrations.CreateModel(
            name="Cashback",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("kind", models.CharField(choices=[("fixed", "Fixed amount"), ("percentage", "Percentage of expense"), ("reward_points", "Reward points (app)")], default="fixed", max_length=20)),
                ("amount", models.DecimalField(decimal_places=2, default=0.0, max_digits=12)),
                ("percentage", models.DecimalField(blank=True, decimal_places=2, max_digits=5, null=True)),
                ("reward_points", models.PositiveIntegerField(blank=True, null=True)),
                ("transaction", models.OneToOneField(help_text="Expense transaction this cashback is for.", on_delete=django.db.models.deletion.CASCADE, related_name="cashback_record", to="finance.transaction")),
                ("reward_app", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="cashback_rewards", to="finance.paymentapp")),
                ("credit_source", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="cashback_credits", to="finance.paymentsource")),
                ("income_transaction", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name="source_cashback", to="finance.transaction")),
            ],
            options={
                "verbose_name": "Cashback",
                "verbose_name_plural": "Cashbacks",
            },
        ),
    ]
