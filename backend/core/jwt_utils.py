"""
JWT encode/decode and auth for API. Uses Django SECRET_KEY for signing.
Requires PyJWT (pip install PyJWT). Do not install the package named 'jwt'.
"""
import time

try:
    import jwt as _jwt
    _jwt.encode   # PyJWT has encode; the wrong 'jwt' package does not
except AttributeError:
    raise ImportError(
        "Wrong 'jwt' package installed. Run: pip uninstall jwt && pip install PyJWT"
    ) from None

from django.conf import settings
from django.contrib.auth import get_user_model
from django.http import JsonResponse

User = get_user_model()

# Token validity (seconds)
JWT_EXPIRY_SECONDS = 60 * 60 * 24 * 7  # 7 days
JWT_ALGORITHM = "HS256"


def jwt_encode(user_id: int, email: str) -> str:
    """Build a JWT containing user id and email with expiry."""
    now = int(time.time())
    payload = {
        "user_id": user_id,
        "email": email,
        "type": "access",
        "iat": now,
        "exp": now + JWT_EXPIRY_SECONDS,
    }
    token = _jwt.encode(
        payload,
        settings.SECRET_KEY,
        algorithm=JWT_ALGORITHM,
    )
    return token if isinstance(token, str) else token.decode("utf-8")


def jwt_decode(token: str) -> dict | None:
    """Decode and validate JWT; return payload or None."""
    try:
        payload = _jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[JWT_ALGORITHM],
        )
        return payload
    except _jwt.InvalidTokenError:
        return None


def get_user_from_request(request):
    """
    If Authorization: Bearer <token> is present and valid, return the User.
    Otherwise return None. Does not send a response.
    """
    auth = request.headers.get("Authorization") or ""
    if not auth.startswith("Bearer "):
        return None
    token = auth[7:].strip()
    if not token:
        return None
    payload = jwt_decode(token)
    if not payload or payload.get("type") != "access":
        return None
    user_id = payload.get("user_id")
    if not user_id:
        return None
    try:
        return User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return None


def jwt_auth_required(view_func):
    """
    Decorator for views that require JWT. Expects Authorization: Bearer <token>.
    Sets request.user from token; returns 401 if missing or invalid.
    """
    def wrapped(request, *args, **kwargs):
        user = get_user_from_request(request)
        if user is None:
            return JsonResponse(
                {"success": False, "message": "Authentication required or invalid token"},
                status=401,
            )
        request.user = user
        return view_func(request, *args, **kwargs)
    return wrapped
