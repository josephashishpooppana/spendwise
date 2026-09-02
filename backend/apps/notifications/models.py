from django.db import models
from django.conf import settings

class BillReminder(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    bill_name = models.CharField(max_length=100) # e.g., "Electricity" or "Amex Due"
    due_date = models.DateField()
    amount_due = models.DecimalField(max_digits=12, decimal_places=2)
    is_paid = models.BooleanField(default=False)
    reminder_days_before = models.IntegerField(default=3)