from django.http import JsonResponse
from django.views.decorators.http import require_GET, require_POST
from django.views.decorators.csrf import ensure_csrf_cookie
from django.contrib.auth import authenticate, login as auth_login
from django.contrib.auth.models import User
from core.jwt_utils import jwt_encode
import json


# Default preferences matching frontend UserPreferences
DEFAULT_PREFERENCES = {
    "currency": "INR",
    "dateFormat": "DD/MM/YYYY",
    "theme": "system",
    "notificationPrefs": {
        "creditCardDue": True,
        "billDue": True,
        "paymentReminder": True,
        "splitSettlement": True,
        "cashbackReceived": True,
        "systemUpdates": True,
    },
}


@ensure_csrf_cookie
@require_GET
def csrf_token(request):
    """Set CSRF cookie for frontend. Path: GET /api/v1/auth/csrf/"""
    return JsonResponse({"detail": "CSRF cookie set"})


def user_to_data(user):
    """Serialize Django User to frontend User shape."""
    return {
        "id": str(user.id),
        "name": user.get_full_name() or user.email or "",
        "email": user.email or "",
        "phone": getattr(user, "phone", "") or "",
        "avatar": getattr(user, "avatar", None),
        "preferences": getattr(user, "preferences", None) or DEFAULT_PREFERENCES,
        "createdAt": user.date_joined.isoformat() if user.date_joined else "",
    }


@require_POST
def login(request):
    data = json.loads(request.body)
    email = data.get("email")
    password = data.get("password")
    user = authenticate(request, username=email, password=password)
    if user is not None:
        auth_login(request, user)
        token = jwt_encode(user.id, user.email)
        return JsonResponse({
            "success": True,
            "data": {
                "user": user_to_data(user),
                "token": token,
            },
        })
    return JsonResponse({"success": False, "message": "Invalid credentials"})


@require_POST
def register(request):
    data = json.loads(request.body)
    name = data.get("name", "").strip()
    first_name = name.split(" ")[0] if name else ""
    last_name = name.replace(first_name, "").strip() if name else ""
    email = data.get("email")
    password = data.get("password")
    user = User.objects.create_user(
        username=email,
        first_name=first_name,
        last_name=last_name,
        email=email,
        password=password,
    )
    token = jwt_encode(user.id, user.email)
    return JsonResponse({
        "success": True,
        "data": {
            "user": user_to_data(user),
            "token": token,
        },
    })


@require_GET
def profile(request):
    """Return current user. request.user set by JWT middleware."""
    return JsonResponse({
        "success": True,
        "data": user_to_data(request.user),
    })