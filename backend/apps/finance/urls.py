from django.urls import path

from apps.finance import views

urlpatterns = [
    path("payment-apps/", views.payment_apps_list, name="payment_apps_list"),
    path("payment-apps/create/", views.payment_app_create, name="payment_app_create"),
    path("payment-apps/<int:app_id>/", views.payment_app_detail, name="payment_app_detail"),
    path("payment-apps/<int:app_id>/link-source/", views.payment_app_link_source, name="payment_app_link_source"),
    path("payment-apps/<int:app_id>/unlink-source/", views.payment_app_unlink_source, name="payment_app_unlink_source"),
    path("payment-methods/", views.payment_methods, name="payment_methods"),
    path("payment-methods/create/", views.payment_method_create, name="payment_method_create"),
    path("payment-methods/<int:method_id>/", views.payment_method_detail, name="payment_method_detail"),

    path("source-types/", views.source_types_list, name="source_types_list"),
    path("payment-sources/", views.payment_sources, name="payment_sources"),
    path("payment-sources/create/", views.payment_source_create, name="payment_source_create"),
    path("payment-sources/<int:source_id>/", views.payment_source_detail, name="payment_source_detail"),

    path("transactions/", views.transactions, name="transactions"),
    path("transactions/create/", views.transaction_create, name="transaction_create"),
    path("transactions/<int:transaction_id>/", views.transaction_detail, name="transaction_detail"),
]