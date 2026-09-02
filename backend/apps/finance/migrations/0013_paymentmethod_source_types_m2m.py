# Replace PaymentMethod allowed_source_types/ids JSON with M2M source_types; make key optional

from django.db import migrations, models


def backfill_source_types_m2m(apps, schema_editor):
    PaymentMethod = apps.get_model("finance", "PaymentMethod")
    SourceType = apps.get_model("finance", "SourceType")
    key_to_id = dict(SourceType.objects.values_list("key", "id"))
    for pm in PaymentMethod.objects.all():
        keys = list(getattr(pm, "allowed_source_types", None) or [])
        if not keys and getattr(pm, "allowed_source_type_ids", None):
            ids = getattr(pm, "allowed_source_type_ids", None) or []
            st_ids = list(SourceType.objects.filter(id__in=ids).values_list("id", flat=True))
        else:
            st_ids = [key_to_id[k] for k in keys if k in key_to_id]
        if st_ids:
            pm.source_types.set(st_ids)


def deduplicate_payment_method_keys(apps, schema_editor):
    """Keep one row per key; set key=None on duplicates so unique constraint can be applied."""
    PaymentMethod = apps.get_model("finance", "PaymentMethod")
    from django.db.models import Count

    # Keys that appear more than once
    dupes = (
        PaymentMethod.objects.exclude(key__isnull=True)
        .exclude(key="")
        .values("key")
        .annotate(c=Count("id"))
        .filter(c__gt=1)
    )
    for d in dupes:
        key_val = d["key"]
        # Keep first by (user null first, then id); clear key on the rest
        rows = list(
            PaymentMethod.objects.filter(key=key_val).order_by("user", "id")
        )
        for pm in rows[1:]:
            pm.key = None
            pm.save(update_fields=["key"])


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0012_paymentsource_source_type_fk"),
    ]

    operations = [
        migrations.AddField(
            model_name="paymentmethod",
            name="source_types",
            field=models.ManyToManyField(
                blank=True,
                help_text="Select one or more payment source types allowed for this method. At least one required.",
                related_name="payment_methods",
                to="finance.sourcetype",
            ),
        ),
        migrations.RunPython(backfill_source_types_m2m, noop),
        migrations.RemoveField(
            model_name="paymentmethod",
            name="allowed_source_types",
        ),
        migrations.RemoveField(
            model_name="paymentmethod",
            name="allowed_source_type_ids",
        ),
        # Make key nullable first so we can set duplicates to None
        migrations.AlterField(
            model_name="paymentmethod",
            name="key",
            field=models.CharField(blank=True, max_length=20, null=True),
        ),
        migrations.RunPython(deduplicate_payment_method_keys, noop),
        # Now add unique
        migrations.AlterField(
            model_name="paymentmethod",
            name="key",
            field=models.CharField(blank=True, max_length=20, null=True, unique=True),
        ),
        migrations.AlterField(
            model_name="paymentmethod",
            name="name",
            field=models.CharField(blank=True, help_text="Display name (e.g. UPI Payment, NEFT)", max_length=100),
        ),
    ]
