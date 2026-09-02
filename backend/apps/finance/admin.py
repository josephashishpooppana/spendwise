from django.contrib import admin
from django.db.models import ProtectedError
from django import forms

from .models import SourceType, PaymentApp, PaymentAppSource, PaymentSource, PaymentMethod, Transaction


class PaymentMethodAdminForm(forms.ModelForm):
    class Meta:
        model = PaymentMethod
        fields = "__all__"

    def clean(self):
        cleaned = super().clean()
        if "source_types" in cleaned and not cleaned["source_types"]:
            raise forms.ValidationError({"source_types": "At least one source type is required."})
        return cleaned


@admin.register(SourceType)
class SourceTypeAdmin(admin.ModelAdmin):
    list_display = ("key", "label", "is_builtin", "payment_sources_count")
    list_editable = ("label",)  # key and is_builtin not editable in list to avoid mistakes
    search_fields = ("key", "label")
    ordering = ("key",)
    list_filter = ("is_builtin",)

    def payment_sources_count(self, obj):
        return obj.payment_sources.count()

    payment_sources_count.short_description = "Payment sources"

    def has_delete_permission(self, request, obj=None):
        if obj is not None and getattr(obj, "is_builtin", False):
            return False
        return super().has_delete_permission(request, obj=obj)

    def delete_model(self, request, obj):
        from django.contrib import messages
        if getattr(obj, "is_builtin", False):
            messages.error(request, "Built-in source types cannot be deleted.")
            return
        try:
            super().delete_model(request, obj)
        except ProtectedError:
            messages.error(request, "This source type is in use by payment sources and cannot be deleted.")


@admin.register(PaymentApp)
class PaymentAppAdmin(admin.ModelAdmin):
    list_display = ("name", "user", "is_active")
    list_filter = ("is_active",)
    search_fields = ("name",)
    raw_id_fields = ("user",)


@admin.register(PaymentAppSource)
class PaymentAppSourceAdmin(admin.ModelAdmin):
    list_display = ("payment_app", "payment_method", "payment_source")
    list_filter = ("payment_app", "payment_method")
    raw_id_fields = ("payment_app", "payment_method", "payment_source")
    ordering = ("payment_app", "payment_method", "payment_source")


@admin.register(PaymentSource)
class PaymentSourceAdmin(admin.ModelAdmin):
    list_display = ("name", "user", "source_type", "balance", "is_active")
    list_filter = ("source_type", "is_active")
    search_fields = ("name", "bank_name")
    raw_id_fields = ("user", "linked_bank_source")
    autocomplete_fields = ("source_type",)


@admin.register(PaymentMethod)
class PaymentMethodAdmin(admin.ModelAdmin):
    form = PaymentMethodAdminForm
    list_display = ("name", "key", "user", "source_types_display", "is_builtin_display")
    list_filter = ("user",)
    search_fields = ("key", "name")
    raw_id_fields = ("user",)
    filter_horizontal = ("source_types",)
    ordering = ("name",)

    def source_types_display(self, obj):
        return ", ".join(obj.source_types.values_list("key", flat=True)) or "—"

    source_types_display.short_description = "Source types"

    def is_builtin_display(self, obj):
        return obj.user_id is None

    is_builtin_display.boolean = True
    is_builtin_display.short_description = "Built-in"

    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj=None, **kwargs)
        return form

    def formfield_for_manytomany(self, db_field, request, **kwargs):
        if db_field.name == "source_types":
            kwargs["help_text"] = "Select at least one source type for this payment method."
        return super().formfield_for_manytomany(db_field, request, **kwargs)


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "type", "amount", "category", "timestamp")
    list_filter = ("type", "timestamp")
    search_fields = ("category", "description")
    raw_id_fields = ("user", "payment_app_id", "payment_method_id", "payment_source_id")
