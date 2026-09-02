from django.db import models
from django.conf import settings
from apps.finance.models import Transaction

class Contact(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    phone_number = models.CharField(max_length=15)
    whatsapp_number = models.CharField(max_length=15, blank=True)
    email = models.EmailField(blank=True)
    upi_id = models.CharField(max_length=100, blank=True)
    bank_details = models.JSONField(default=dict, help_text="Store IFSC, Acc No, etc.")

class Group(models.Model):
    name = models.CharField(max_length=100)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    members = models.ManyToManyField(Contact, related_name='expense_groups')

class BillSplit(models.Model):
    SPLIT_TYPES = (('EQUAL', 'Equal'), ('CUSTOM', 'Custom Amount'))
    
    transaction = models.OneToOneField(Transaction, on_delete=models.CASCADE)
    group = models.ForeignKey(Group, on_delete=models.SET_NULL, null=True)
    split_type = models.CharField(max_length=10, choices=SPLIT_TYPES)
    
    # Store who owes what in a JSON structure for flexibility
    # Format: {"contact_id": 50.00, "contact_id_2": 25.00}
    split_details = models.JSONField() 
    is_settled = models.BooleanField(default=False)