# Update UPI payment method: source_types from BANK,WALLET to CREDIT_CARD,DEBIT_CARD

from django.db import migrations


def upi_source_types_to_credit_debit(apps, schema_editor):
    PaymentMethod = apps.get_model("finance", "PaymentMethod")
    SourceType = apps.get_model("finance", "SourceType")
    key_to_id = dict(SourceType.objects.values_list("key", "id"))
    pm = PaymentMethod.objects.filter(key="UPI", user__isnull=True).first()
    if not pm:
        return
    st_ids = [key_to_id[k] for k in ("CREDIT_CARD", "DEBIT_CARD") if k in key_to_id]
    if st_ids:
        pm.source_types.set(st_ids)


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0015_app_source_links_remove_payment_app_from_source"),
    ]

    operations = [
        migrations.RunPython(upi_source_types_to_credit_debit, noop),
    ]
