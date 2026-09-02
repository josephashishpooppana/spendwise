# Generated manually - replace PaymentSource.source_type CharField with FK to SourceType

from django.db import migrations, models
import django.db.models.deletion


def backfill_source_type_fk(apps, schema_editor):
    PaymentSource = apps.get_model("finance", "PaymentSource")
    SourceType = apps.get_model("finance", "SourceType")
    key_to_id = dict(SourceType.objects.values_list("key", "id"))
    for ps in PaymentSource.objects.all():
        key = ps.source_type  # CharField value at this migration step
        if key in key_to_id:
            ps.source_type_fk_id = key_to_id[key]
            ps.save(update_fields=["source_type_fk_id"])


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0011_add_sourcetype_is_builtin"),
    ]

    operations = [
        migrations.AddField(
            model_name="paymentsource",
            name="source_type_fk",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name="+",
                to="finance.sourcetype",
                help_text="Type of payment source (bank, card, wallet, etc.). Managed in Payment source types.",
            ),
        ),
        migrations.RunPython(backfill_source_type_fk, noop),
        migrations.RemoveField(
            model_name="paymentsource",
            name="source_type",
        ),
        migrations.RenameField(
            model_name="paymentsource",
            old_name="source_type_fk",
            new_name="source_type",
        ),
        migrations.AlterField(
            model_name="paymentsource",
            name="source_type",
            field=models.ForeignKey(
                help_text="Type of payment source (bank, card, wallet, etc.). Managed in Payment source types.",
                on_delete=django.db.models.deletion.PROTECT,
                related_name="payment_sources",
                to="finance.sourcetype",
            ),
        ),
    ]
