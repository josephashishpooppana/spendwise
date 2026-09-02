# Generated manually - add allowed_source_type_ids to PaymentMethod

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("finance", "0009_add_source_type_and_method_allowed_sources"),
    ]

    operations = [
        migrations.AddField(
            model_name="paymentmethod",
            name="allowed_source_type_ids",
            field=models.JSONField(blank=True, default=list, help_text="List of source type ids, e.g. [1, 2, 3]"),
        ),
    ]
