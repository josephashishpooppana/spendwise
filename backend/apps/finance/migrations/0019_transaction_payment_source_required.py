# Revert payment_source_id to non-nullable (source is required for all transactions)

from django.db import migrations, models
import django.db.models.deletion


def ensure_no_null_sources(apps, schema_editor):
    """Set any NULL payment_source_id to the user's first payment source (safety for existing data)."""
    Transaction = apps.get_model("finance", "Transaction")
    PaymentSource = apps.get_model("finance", "PaymentSource")
    for txn in Transaction.objects.filter(payment_source_id__isnull=True).select_related("user"):
        first = PaymentSource.objects.filter(user_id=txn.user_id).order_by("id").first()
        if first:
            txn.payment_source_id = first
            txn.save(update_fields=["payment_source_id"])


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0018_transaction_payment_source_nullable'),
    ]

    operations = [
        migrations.RunPython(ensure_no_null_sources, migrations.RunPython.noop),
        migrations.AlterField(
            model_name='transaction',
            name='payment_source_id',
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.PROTECT,
                related_name='transactions',
                to='finance.paymentsource',
            ),
        ),
    ]
