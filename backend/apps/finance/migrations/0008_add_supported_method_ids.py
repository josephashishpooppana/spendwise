# Generated manually

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0007_remove_transaction_payment_app_name_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='paymentapp',
            name='supported_method_ids',
            field=models.JSONField(default=list, help_text='e.g. [1, 9, 11]'),
        ),
    ]
