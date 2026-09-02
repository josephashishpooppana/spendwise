# Generated manually - add is_builtin to SourceType and mark built-in types

from django.db import migrations, models


def set_builtin_source_types(apps, schema_editor):
    SourceType = apps.get_model("finance", "SourceType")
    builtin_keys = ("BANK", "CREDIT_CARD", "DEBIT_CARD", "WALLET", "CASH")
    SourceType.objects.filter(key__in=builtin_keys).update(is_builtin=True)


def noop(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0010_add_allowed_source_type_ids"),
    ]

    operations = [
        migrations.AddField(
            model_name="sourcetype",
            name="is_builtin",
            field=models.BooleanField(
                default=False,
                help_text="Built-in types are created by migration; prevent accidental deletion.",
            ),
        ),
        migrations.RunPython(set_builtin_source_types, noop),
    ]
