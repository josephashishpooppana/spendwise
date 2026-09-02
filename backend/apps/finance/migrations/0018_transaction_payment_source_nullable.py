# Generated manually for optional payment source on income

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('finance', '0017_alter_paymentmethod_options_alter_sourcetype_options_and_more'),
    ]

    operations = [
        migrations.AlterField(
            model_name='transaction',
            name='payment_source_id',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name='transactions',
                to='finance.paymentsource',
            ),
        ),
    ]
