"""
Middleware to set request.user from JWT on API requests.
Skip for auth endpoints that don't require a token (login, register, csrf).
"""
from django.http import JsonResponse
from core.jwt_utils import get_user_from_request

# Paths under /api/v1/ that do NOT require JWT (login, register, csrf)
JWT_EXEMPT_PREFIXES = (
    "/api/v1/auth/login/",
    "/api/v1/auth/register/",
    "/api/v1/auth/csrf/",
)


def jwt_user_middleware(get_response):
    def middleware(request):
        path = request.path
        if path.startswith("/api/v1/") and not any(path.startswith(p) for p in JWT_EXEMPT_PREFIXES):
            user = get_user_from_request(request)
            if user is None:
                return JsonResponse(
                    {"success": False, "message": "Authentication required or invalid token"},
                    status=401,
                )
            request.user = user
        return get_response(request)
    return middleware
