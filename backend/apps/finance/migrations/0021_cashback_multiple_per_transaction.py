# Allow multiple cashback entries per transaction (cashback + reward points)

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0020_cashback"),
    ]

    operations = [
        migrations.AlterField(
            model_name="cashback",
            name="transaction",
            field=models.ForeignKey(
                help_text="Expense transaction this cashback is for.",
                on_delete=django.db.models.deletion.CASCADE,
                related_name="cashback_records",
                to="finance.transaction",
            ),
        ),
    ]
