from django.urls import path

from apps.accounts import views

urlpatterns = [
    path("csrf/", views.csrf_token, name="csrf_token"),
    path("login/", views.login, name="login"),
    path("register/", views.register, name="register"),
    path("profile/", views.profile, name="profile"),
]