from django.http import JsonResponse
from django.views.decorators.http import require_GET, require_POST
from django.views.decorators.csrf import ensure_csrf_cookie


@ensure_csrf_cookie
@require_GET
def csrf_token(request):
    """Return 200 and set CSRF cookie so the frontend can send it back on POST."""
    return JsonResponse({"detail": "CSRF cookie set"})