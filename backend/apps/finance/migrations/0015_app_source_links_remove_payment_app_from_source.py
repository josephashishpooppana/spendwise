# Add PaymentAppSource link table; remove payment_app from PaymentSource.
# A source can be linked to multiple apps via (app, method, source); backfill from existing payment_app.

import json
from django.db import migrations, models
import django.db.models.deletion


def _parse_method_ids(raw):
    """Normalize supported_method_ids: list of ints, or string (JSON array / comma-separated)."""
    if raw is None:
        return []
    if isinstance(raw, list):
        return raw
    if isinstance(raw, str):
        s = raw.strip()
        if not s:
            return []
        if s.startswith("["):
            try:
                parsed = json.loads(s)
                return parsed if isinstance(parsed, list) else []
            except json.JSONDecodeError:
                pass
        return [p.strip() for p in s.replace(",", " ").split() if p.strip()]
    return []


def backfill_app_source_links(apps, schema_editor):
    PaymentSource = apps.get_model("finance", "PaymentSource")
    PaymentApp = apps.get_model("finance", "PaymentApp")
    PaymentMethod = apps.get_model("finance", "PaymentMethod")
    PaymentAppSource = apps.get_model("finance", "PaymentAppSource")

    # Only sources that have a non-null payment_app (ForeignKey expects int, not "")
    for source in PaymentSource.objects.exclude(payment_app_id__isnull=True):
        app_id = source.payment_app_id
        if app_id is None:
            continue
        try:
            app = PaymentApp.objects.get(id=app_id)
        except PaymentApp.DoesNotExist:
            continue
        raw_ids = getattr(app, "supported_method_ids", None) or []
        method_ids = _parse_method_ids(raw_ids)
        for mid in method_ids:
            if mid is None or mid == "":
                continue
            try:
                method = PaymentMethod.objects.get(id=int(mid))
            except (PaymentMethod.DoesNotExist, ValueError, TypeError):
                continue
            PaymentAppSource.objects.get_or_create(
                payment_app_id=app.id,
                payment_method_id=method.id,
                payment_source_id=source.id,
            )


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0014_create_builtin_payment_methods"),
    ]

    operations = [
        migrations.CreateModel(
            name="PaymentAppSource",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("payment_app", models.ForeignKey(
                    help_text="App this source is linked to.",
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="source_links",
                    to="finance.paymentapp",
                )),
                ("payment_method", models.ForeignKey(
                    help_text="Method within the app that can use this source.",
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="app_source_links",
                    to="finance.paymentmethod",
                )),
                ("payment_source", models.ForeignKey(
                    help_text="Payment source linked to the app for this method.",
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="app_links",
                    to="finance.paymentsource",
                )),
            ],
            options={
                "ordering": ["payment_app", "payment_method", "payment_source"],
                "verbose_name": "App–source link",
                "verbose_name_plural": "App–source links",
            },
        ),
        migrations.AddConstraint(
            model_name="paymentappsource",
            constraint=models.UniqueConstraint(
                fields=("payment_app", "payment_method", "payment_source"),
                name="finance_paymentappsource_unique_app_method_source",
            ),
        ),
        migrations.RunPython(backfill_app_source_links, noop),
        migrations.RemoveField(
            model_name="paymentsource",
            name="payment_app",
        ),
    ]
