from django.db.models import F
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.http import require_http_methods

from apps.finance.models import (
    Transaction,
    PaymentSource,
    PaymentApp,
    PaymentMethod,
    SourceType,
    PaymentAppSource,
    Cashback,
)
from core.jwt_utils import jwt_auth_required
import json
import logging

logger = logging.getLogger(__name__)

# Backend METHOD key -> frontend PaymentMethodType (camelCase keys for frontend)
BACKEND_TO_FRONTEND_TYPE = {
    "UPI": "upi",
    "CASH": "cash",
    "ATM": "atm",
    "CREDIT_CARD": "credit_card",
    "DEBIT_CARD": "debit_card",
    "WALLET": "wallet",
    "NET_BANKING": "net_banking",
    "TRANSFER": "bank_transfer",
    "CHECK": "other",
    "OTHER": "other",
}
# Frontend paymentMethodType -> backend METHOD key (for transaction create)
FRONTEND_TO_BACKEND_METHOD = {v: k for k, v in BACKEND_TO_FRONTEND_TYPE.items()}


def _payment_method_allowed_keys(pm):
    """Return list of source type keys allowed for this payment method."""
    return list(pm.source_types.values_list("key", flat=True))


def _payment_method_allowed_ids(pm):
    """Return list of source type ids allowed for this payment method."""
    return list(pm.source_types.values_list("id", flat=True))


def _parse_supported_method_ids(raw):
    """Normalize supportedMethodIds from request: accept list or string (comma-separated or JSON array)."""
    if raw is None:
        return []
    if isinstance(raw, list):
        return raw
    if isinstance(raw, str):
        s = raw.strip()
        if not s:
            return []
        # Try JSON array first, e.g. "[1,2,3]"
        if s.startswith("["):
            try:
                parsed = json.loads(s)
                return parsed if isinstance(parsed, list) else []
            except json.JSONDecodeError:
                pass
        # Comma- or space-separated ids
        return [p.strip() for p in s.replace(",", " ").split() if p.strip()]
    return []


@jwt_auth_required
def payment_apps_list(request):
    """Return list of user's payment apps. Default: active only. ?all=1 for management (all apps)."""
    all_apps = request.GET.get("all") == "1"
    qs = PaymentApp.objects.filter(user=request.user).order_by("name")
    if not all_apps:
        qs = qs.filter(is_active=True)
    now = timezone.now().isoformat()
    data = [
        {
            "id": str(a.id),
            "name": a.name,
            "supportedMethods": getattr(a, "supported_methods", None) or [],
            "supportedMethodIds": [str(x) for x in (getattr(a, "supported_method_ids", None) or [])],
            "isActive": a.is_active,
            "createdAt": getattr(a, "created_at", None) or now,
        }
        for a in qs
    ]
    return JsonResponse({"success": True, "data": data})


@jwt_auth_required
@require_http_methods(["POST"])
def payment_app_create(request):
    """Create a new payment app. Accepts supportedMethodIds (list of PaymentMethod ids) or supportedMethods (keys)."""
    try:
        body = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"success": False, "message": "Invalid JSON"}, status=400)
    name = (body.get("name") or "").strip()
    if not name:
        return JsonResponse({"success": False, "message": "Name is required"}, status=400)

    supported_method_ids = []
    raw_ids = _parse_supported_method_ids(body.get("supportedMethodIds"))
    for raw_id in raw_ids:
        if raw_id is None or raw_id == "":
            continue
        try:
            pm = PaymentMethod.objects.get(id=int(raw_id))
            if pm.user_id is None or pm.user_id == request.user.id:
                supported_method_ids.append(pm.id)
        except (PaymentMethod.DoesNotExist, ValueError, TypeError):
            pass
    if not supported_method_ids and "supportedMethods" in body:
        supported_methods = body["supportedMethods"]
        if isinstance(supported_methods, list):
            supported_methods = [str(m).strip().upper() for m in supported_methods if m]
            valid_keys = set(
                PaymentMethod.objects.filter(user__isnull=True)
                .exclude(key__isnull=True)
                .values_list("key", flat=True)
            )
            for key in supported_methods:
                if key in valid_keys:
                    pm = PaymentMethod.objects.filter(key=key, user__isnull=True).first()
                    if pm:
                        supported_method_ids.append(pm.id)

    keys_from_ids = list(
        dict.fromkeys(
            PaymentMethod.objects.filter(id__in=supported_method_ids).values_list("key", flat=True)
        )
    )
    # Filter out None for custom methods that have no key
    keys_from_ids = [k for k in keys_from_ids if k is not None]
    app = PaymentApp.objects.create(
        user=request.user,
        name=name,
        supported_methods=keys_from_ids,
        supported_method_ids=supported_method_ids,
        is_active=body.get("isActive", True),
    )
    return JsonResponse({
        "success": True,
        "data": {
            "id": str(app.id),
            "name": app.name,
            "supportedMethods": app.supported_methods,
            "supportedMethodIds": [str(x) for x in app.supported_method_ids],
            "isActive": app.is_active,
            "createdAt": timezone.now().isoformat(),
        },
        "message": "App created",
    }, status=201)


@jwt_auth_required
def payment_app_detail(request, app_id):
    """Get or update or delete a single payment app."""
    try:
        app = PaymentApp.objects.get(id=app_id, user=request.user)
    except PaymentApp.DoesNotExist:
        return JsonResponse({"success": False, "message": "Not found"}, status=404)

    if request.method == "GET":
        return JsonResponse({
            "success": True,
            "data": {
                "id": str(app.id),
                "name": app.name,
                "supportedMethods": getattr(app, "supported_methods", None) or [],
                "supportedMethodIds": [str(x) for x in (getattr(app, "supported_method_ids", None) or [])],
                "isActive": app.is_active,
                "createdAt": getattr(app, "created_at", None) or timezone.now().isoformat(),
            },
        })

    if request.method in ("PUT", "PATCH"):
        try:
            body = json.loads(request.body)
        except json.JSONDecodeError:
            return JsonResponse({"success": False, "message": "Invalid JSON"}, status=400)
        if "name" in body:
            name = (body.get("name") or "").strip()
            if name:
                app.name = name
        if "supportedMethodIds" in body:
            raw_ids = _parse_supported_method_ids(body["supportedMethodIds"])
            supported_method_ids = []
            for raw_id in raw_ids:
                if raw_id is None or raw_id == "":
                    continue
                try:
                    pm = PaymentMethod.objects.get(id=int(raw_id))
                    if pm.user_id is None or pm.user_id == request.user.id:
                        supported_method_ids.append(pm.id)
                except (PaymentMethod.DoesNotExist, ValueError, TypeError):
                    pass
            app.supported_method_ids = supported_method_ids
            keys_from_ids = list(
                dict.fromkeys(
                    PaymentMethod.objects.filter(id__in=supported_method_ids).values_list("key", flat=True)
                )
            )
            app.supported_methods = [k for k in keys_from_ids if k is not None]
        elif "supportedMethods" in body:
            sm = body["supportedMethods"]
            if isinstance(sm, list):
                sm = [str(m).strip().upper() for m in sm if m]
                valid_keys = set(
                    PaymentMethod.objects.filter(user__isnull=True)
                    .exclude(key__isnull=True)
                    .values_list("key", flat=True)
                )
                app.supported_methods = [m for m in sm if m in valid_keys]
                app.supported_method_ids = list(
                    PaymentMethod.objects.filter(key__in=app.supported_methods, user__isnull=True).values_list("id", flat=True)
                )
        if "isActive" in body:
            app.is_active = bool(body["isActive"])
        app.save()
        return JsonResponse({
            "success": True,
            "data": {
                "id": str(app.id),
                "name": app.name,
                "supportedMethods": app.supported_methods,
                "supportedMethodIds": [str(x) for x in (app.supported_method_ids or [])],
                "isActive": app.is_active,
                "createdAt": timezone.now().isoformat(),
            },
            "message": "App updated",
        })

    if request.method == "DELETE":
        app.delete()
        return JsonResponse({"success": True, "message": "App deleted"})

    return JsonResponse({"success": False, "message": "Method not allowed"}, status=405)


@jwt_auth_required
@require_http_methods(["POST"])
def payment_app_link_source(request, app_id):
    """Link a payment source to this app for the given method(s). Body: { sourceId, methodIds: [id, ...] }."""
    try:
        app = PaymentApp.objects.get(id=app_id, user=request.user)
    except PaymentApp.DoesNotExist:
        return JsonResponse({"success": False, "message": "App not found"}, status=404)
    try:
        body = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"success": False, "message": "Invalid JSON"}, status=400)
    source_id = body.get("sourceId") or body.get("source_id")
    if not source_id:
        return JsonResponse({"success": False, "message": "sourceId is required"}, status=400)
    try:
        source = PaymentSource.objects.get(id=source_id, user=request.user)
    except (PaymentSource.DoesNotExist, ValueError):
        return JsonResponse({"success": False, "message": "Source not found"}, status=404)
    method_ids = body.get("methodIds") or body.get("method_ids") or []
    if not isinstance(method_ids, list):
        method_ids = []
    # Normalize to ints: JSONField may return int or str
    raw_allowed = app.supported_method_ids or []
    allowed_ids = set()
    for x in raw_allowed:
        try:
            allowed_ids.add(int(x))
        except (ValueError, TypeError):
            pass
    created = 0
    for mid in method_ids:
        try:
            mid_int = int(mid)
        except (ValueError, TypeError):
            continue
        try:
            method = PaymentMethod.objects.get(id=mid_int)
        except PaymentMethod.DoesNotExist:
            continue
        # Allow if: method is in app's supported list, or method is user's custom (so linking works before app save)
        if mid_int not in allowed_ids and (method.user_id is None or method.user_id != request.user.id):
            continue
        _, created_this = PaymentAppSource.objects.get_or_create(
            payment_app=app,
            payment_method=method,
            payment_source=source,
        )
        if created_this:
            created += 1
    return JsonResponse({
        "success": True,
        "message": f"Source linked for {created} method(s)",
        "data": {"linkedCount": created},
    })


@jwt_auth_required
@require_http_methods(["POST"])
def payment_app_unlink_source(request, app_id):
    """Remove a payment source from this app. Body: { sourceId, methodIds?: [id, ...] }. If methodIds omitted, unlink from all methods."""
    try:
        app = PaymentApp.objects.get(id=app_id, user=request.user)
    except PaymentApp.DoesNotExist:
        return JsonResponse({"success": False, "message": "App not found"}, status=404)
    try:
        body = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"success": False, "message": "Invalid JSON"}, status=400)
    source_id = body.get("sourceId") or body.get("source_id")
    if not source_id:
        return JsonResponse({"success": False, "message": "sourceId is required"}, status=400)
    try:
        source = PaymentSource.objects.get(id=source_id, user=request.user)
    except (PaymentSource.DoesNotExist, ValueError):
        return JsonResponse({"success": False, "message": "Source not found"}, status=404)
    method_ids = body.get("methodIds") or body.get("method_ids")
    if method_ids is not None and not isinstance(method_ids, list):
        method_ids = None
    qs = PaymentAppSource.objects.filter(payment_app=app, payment_source=source)
    if method_ids is not None and len(method_ids) > 0:
        mid_ints = []
        for mid in method_ids:
            try:
                mid_ints.append(int(mid))
            except (ValueError, TypeError):
                pass
        if mid_ints:
            qs = qs.filter(payment_method_id__in=mid_ints)
    deleted, _ = qs.delete()
    return JsonResponse({
        "success": True,
        "message": f"Source unlinked ({deleted} link(s) removed)",
        "data": {"unlinkedCount": deleted},
    })


@jwt_auth_required
def source_types_list(request):
    """Return all source types (key, label) for dropdowns. Editable in Django admin."""
    qs = SourceType.objects.all().order_by("key")
    data = [{"key": st.key, "label": st.label} for st in qs]
    return JsonResponse({"success": True, "data": data})


@jwt_auth_required
def payment_methods(request):
    """
    Return payment methods with real PKs from PaymentMethod model.
    If app_id is provided, only methods supported by that app.
    If management=1, return all methods (built-in + user's custom) with key and isBuiltIn for CRUD UI.
    """
    management = request.GET.get("management") == "1"
    if management:
        # For CRUD UI: built-in (user=None) + user's custom methods
        qs_builtin = PaymentMethod.objects.prefetch_related("source_types").filter(user__isnull=True).order_by("name")
        qs_custom = PaymentMethod.objects.prefetch_related("source_types").filter(user=request.user).order_by("name")
        now = timezone.now().isoformat()
        data = []
        for pm in qs_builtin:
            data.append({
                "id": str(pm.id),
                "key": pm.key,
                "type": BACKEND_TO_FRONTEND_TYPE.get(pm.key, "other"),
                "name": pm.name or pm.key or str(pm.id),
                "isActive": True,
                "isBuiltIn": True,
                "allowedSourceTypes": _payment_method_allowed_keys(pm),
                "allowedSourceTypeIds": _payment_method_allowed_ids(pm),
                "details": {},
                "createdAt": now,
            })
        for pm in qs_custom:
            data.append({
                "id": str(pm.id),
                "key": pm.key,
                "type": BACKEND_TO_FRONTEND_TYPE.get(pm.key, "other"),
                "name": pm.name or pm.key or str(pm.id),
                "isActive": True,
                "isBuiltIn": False,
                "allowedSourceTypes": _payment_method_allowed_keys(pm),
                "allowedSourceTypeIds": _payment_method_allowed_ids(pm),
                "details": {},
                "createdAt": now,
            })
        return JsonResponse({"success": True, "data": data})

    app_id = request.GET.get("app_id")
    if app_id and app_id != "none":
        try:
            app = PaymentApp.objects.get(id=app_id, user=request.user)
            ids = getattr(app, "supported_method_ids", None) or []
            if ids:
                qs = PaymentMethod.objects.prefetch_related("source_types").filter(id__in=ids).order_by("name")
            else:
                supported = app.supported_methods or []
                if not supported:
                    qs = PaymentMethod.objects.prefetch_related("source_types").filter(user__isnull=True).order_by("name")
                else:
                    qs = PaymentMethod.objects.prefetch_related("source_types").filter(user__isnull=True, key__in=supported).order_by("name")
        except PaymentApp.DoesNotExist:
            qs = PaymentMethod.objects.prefetch_related("source_types").filter(user__isnull=True).order_by("name")
    else:
        qs = PaymentMethod.objects.prefetch_related("source_types").filter(user__isnull=True).order_by("name")

    now = timezone.now().isoformat()
    data = [
        {
            "id": str(pm.id),
            "type": BACKEND_TO_FRONTEND_TYPE.get(pm.key, "other"),
            "name": pm.name or pm.key or str(pm.id),
            "key": getattr(pm, "key", None),
            "allowedSourceTypes": _payment_method_allowed_keys(pm),
            "allowedSourceTypeIds": _payment_method_allowed_ids(pm),
            "isActive": True,
            "details": {},
            "createdAt": now,
        }
        for pm in qs
    ]
    return JsonResponse({"success": True, "data": data})


def _serialize_payment_method(pm):
    """Serialize a PaymentMethod for API response."""
    now = timezone.now().isoformat()
    return {
        "id": str(pm.id),
        "key": pm.key,
        "type": BACKEND_TO_FRONTEND_TYPE.get(pm.key, "other"),
        "name": pm.name or pm.key or str(pm.id),
        "isActive": True,
        "isBuiltIn": pm.user_id is None,
        "allowedSourceTypes": _payment_method_allowed_keys(pm),
        "allowedSourceTypeIds": _payment_method_allowed_ids(pm),
        "details": {},
        "createdAt": now,
    }


@jwt_auth_required
@require_http_methods(["POST"])
def payment_method_create(request):
    """Create a user-specific payment method. Requires name and at least one source type (by key or id)."""
    try:
        body = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"success": False, "message": "Invalid JSON"}, status=400)
    name = (body.get("name") or "").strip()
    if not name:
        return JsonResponse({"success": False, "message": "Name is required"}, status=400)

    source_type_ids = []
    if "sourceTypeIds" in body and isinstance(body["sourceTypeIds"], list):
        for sid in body["sourceTypeIds"]:
            if sid is not None and sid != "":
                try:
                    st = SourceType.objects.get(id=int(sid))
                    source_type_ids.append(st.id)
                except (SourceType.DoesNotExist, ValueError, TypeError):
                    pass
    if not source_type_ids and "sourceTypeKeys" in body and isinstance(body["sourceTypeKeys"], list):
        keys = [str(k).strip().upper() for k in body["sourceTypeKeys"] if k]
        source_type_ids = list(SourceType.objects.filter(key__in=keys).values_list("id", flat=True))
    if not source_type_ids:
        return JsonResponse({
            "success": False,
            "message": "At least one source type is required (sourceTypeIds or sourceTypeKeys).",
        }, status=400)

    pm = PaymentMethod.objects.create(user=request.user, name=name, key=None)
    pm.source_types.set(source_type_ids)
    return JsonResponse({
        "success": True,
        "data": _serialize_payment_method(pm),
        "message": "Payment method created",
    }, status=201)


@jwt_auth_required
@require_http_methods(["GET", "PUT", "PATCH", "DELETE"])
def payment_method_detail(request, method_id):
    """Get, update, or delete a single payment method. Built-in (user=None) are read-only."""
    try:
        pm = PaymentMethod.objects.prefetch_related("source_types").get(id=method_id)
    except PaymentMethod.DoesNotExist:
        return JsonResponse({"success": False, "message": "Not found"}, status=404)
    # Built-in: only GET allowed. Custom: owner can GET/PUT/DELETE.
    is_builtin = pm.user_id is None
    if is_builtin and request.method != "GET":
        return JsonResponse({"success": False, "message": "Built-in payment methods cannot be edited or deleted"}, status=403)
    if not is_builtin and pm.user_id != request.user.id:
        return JsonResponse({"success": False, "message": "Not found"}, status=404)

    if request.method == "GET":
        return JsonResponse({"success": True, "data": _serialize_payment_method(pm)})

    if request.method in ("PUT", "PATCH"):
        try:
            body = json.loads(request.body)
        except json.JSONDecodeError:
            return JsonResponse({"success": False, "message": "Invalid JSON"}, status=400)
        if "name" in body:
            name = (body.get("name") or "").strip()
            if name:
                pm.name = name
        if "sourceTypeIds" in body and isinstance(body["sourceTypeIds"], list):
            ids = []
            for sid in body["sourceTypeIds"]:
                if sid is not None and sid != "":
                    try:
                        ids.append(int(sid))
                    except (ValueError, TypeError):
                        pass
            if ids:
                pm.source_types.set(ids)
        elif "sourceTypeKeys" in body and isinstance(body["sourceTypeKeys"], list):
            keys = [str(k).strip().upper() for k in body["sourceTypeKeys"] if k]
            if keys:
                pm.source_types.set(list(SourceType.objects.filter(key__in=keys).values_list("id", flat=True)))
        pm.save()
        return JsonResponse({"success": True, "data": _serialize_payment_method(pm), "message": "Updated"})

    if request.method == "DELETE":
        pm.delete()
        return JsonResponse({"success": True, "message": "Deleted"})

    return JsonResponse({"success": False, "message": "Method not allowed"}, status=405)


# Frontend PaymentSourceType: bank | credit_card | debit_card | wallet | cash
BACKEND_TO_FRONTEND_SOURCE = {
    "BANK": "bank",
    "CREDIT_CARD": "credit_card",
    "DEBIT_CARD": "debit_card",
    "WALLET": "wallet",
    "CASH": "cash",
}


@jwt_auth_required
def payment_sources(request):
    """
    Return payment sources. Optional query params:
    - app_id: filter by payment app (sources linked to this app). Use "none" for standalone (not linked to any app).
    - method: filter by payment method key (UPI, CREDIT_CARD, etc.) so only compatible source_type are returned.
    - all=1: include inactive sources (for management).
    """
    qs = PaymentSource.objects.filter(user=request.user).select_related(
        "linked_bank_source", "source_type"
    ).prefetch_related("app_links__payment_app").order_by("name")
    if request.GET.get("all") != "1":
        qs = qs.filter(is_active=True)
    app_id = request.GET.get("app_id")
    method = (request.GET.get("method") or "").strip().upper()

    if app_id:
        if app_id == "none":
            # Standalone: sources that have no app links
            linked_source_ids = PaymentAppSource.objects.values_list("payment_source_id", flat=True).distinct()
            qs = qs.exclude(id__in=linked_source_ids)
        else:
            # Sources linked to this app (via PaymentAppSource)
            qs = qs.filter(app_links__payment_app_id=app_id).distinct()

    if method:
        # method can be payment method key (e.g. UPI) or id
        try:
            method_id = int(method)
            pm = PaymentMethod.objects.prefetch_related("source_types").filter(id=method_id).first()
        except ValueError:
            pm = PaymentMethod.objects.prefetch_related("source_types").filter(key=method).first()
        if pm:
            allowed_keys = _payment_method_allowed_keys(pm)
            if allowed_keys:
                qs = qs.filter(source_type__key__in=allowed_keys)

    now = timezone.now().isoformat()
    data = []
    for s in qs:
        st_key = s.source_type.key if s.source_type_id else None
        linked_apps = list(s.app_links.all())
        # Preserve order so linkedAppIds[i] matches linkedAppNames[i]
        seen = {}
        for link in linked_apps:
            aid = getattr(link, "payment_app_id", None)
            if aid is not None and aid not in seen:
                seen[aid] = link.payment_app.name if getattr(link, "payment_app", None) else str(aid)
        app_ids = [str(aid) for aid in seen]
        app_names = [seen[aid] for aid in seen]
        # Debit card: show linked bank balance; others use source balance
        if st_key == "DEBIT_CARD" and s.linked_bank_source_id and getattr(s, "linked_bank_source", None):
            display_balance = float(s.linked_bank_source.balance)
        else:
            display_balance = float(s.balance)
        payload = {
            "id": str(s.id),
            "type": BACKEND_TO_FRONTEND_SOURCE.get(st_key, "bank"),
            "name": s.name,
            "bankName": s.bank_name or None,
            "balance": display_balance,
            "sourceType": st_key,
            "isActive": s.is_active,
            "createdAt": now,
            "linkedAppIds": app_ids,
            "linkedAppNames": app_names,
            "linkedBankSourceId": str(s.linked_bank_source_id) if s.linked_bank_source_id else None,
            "linkedBankSourceName": s.linked_bank_source.name if s.linked_bank_source else None,
        }
        if app_id and app_id != "none":
            try:
                aid = int(app_id)
                linked_for_method_ids = [str(link.payment_method_id) for link in linked_apps if getattr(link, "payment_app_id", None) == aid]
                payload["linkedForAppMethodIds"] = linked_for_method_ids
            except ValueError:
                pass
        data.append(payload)
    return JsonResponse({"success": True, "data": data})


@jwt_auth_required
@require_http_methods(["POST"])
def payment_source_create(request):
    """Create a payment source (optionally linked to an app)."""
    try:
        body = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"success": False, "message": "Invalid JSON"}, status=400)
    name = (body.get("name") or "").strip()
    if not name:
        return JsonResponse({"success": False, "message": "Name is required"}, status=400)
    source_type_key = (body.get("sourceType") or body.get("source_type") or "").strip().upper()
    try:
        source_type_obj = SourceType.objects.get(key=source_type_key)
    except SourceType.DoesNotExist:
        valid_keys = list(SourceType.objects.values_list("key", flat=True))
        return JsonResponse({
            "success": False,
            "message": f"Valid sourceType is required. Allowed: {', '.join(valid_keys)}",
        }, status=400)
    linked_bank_source = None
    linked_bank_id = body.get("linkedBankSourceId") or body.get("linked_bank_source_id")
    if linked_bank_id and str(linked_bank_id).strip():
        try:
            linked = PaymentSource.objects.select_related("source_type").get(id=linked_bank_id, user=request.user)
            if linked.source_type.key != "BANK":
                return JsonResponse({"success": False, "message": "Linked bank source must be a bank account"}, status=400)
            linked_bank_source = linked
        except (PaymentSource.DoesNotExist, ValueError):
            return JsonResponse({"success": False, "message": "Linked bank source not found"}, status=400)
    if source_type_key == "DEBIT_CARD" and not linked_bank_source:
        return JsonResponse({"success": False, "message": "Debit card requires a linked bank account"}, status=400)
    # Debit card balance = linked bank account balance; others use body or 0
    if source_type_key == "DEBIT_CARD" and linked_bank_source:
        initial_balance = float(linked_bank_source.balance)
    else:
        initial_balance = float(body.get("balance", 0))
    source = PaymentSource.objects.create(
        user=request.user,
        linked_bank_source=linked_bank_source,
        name=name,
        bank_name=(body.get("bankName") or body.get("bank_name") or "").strip()[:100],
        source_type=source_type_obj,
        balance=initial_balance,
        is_active=body.get("isActive", body.get("is_active", True)),
    )
    # Optionally link to app(s) and method(s): linkToAppId + linkToMethodIds (list of method ids for that app)
    link_app_id = body.get("linkToAppId") or body.get("link_to_app_id")
    link_method_ids = body.get("linkToMethodIds") or body.get("link_to_method_ids")
    if link_app_id and str(link_app_id).strip() and isinstance(link_method_ids, list):
        try:
            app = PaymentApp.objects.get(id=link_app_id, user=request.user)
            for mid in link_method_ids:
                if mid is None or mid == "" or not str(mid).strip():
                    continue
                try:
                    method = PaymentMethod.objects.get(id=int(mid))
                    PaymentAppSource.objects.get_or_create(
                        payment_app=app,
                        payment_method=method,
                        payment_source=source,
                    )
                except (PaymentMethod.DoesNotExist, ValueError, TypeError):
                    pass
        except (PaymentApp.DoesNotExist, ValueError, TypeError):
            pass
    st_key = source.source_type.key
    linked_app_ids = list(source.app_links.values_list("payment_app_id", flat=True).distinct())
    linked_apps = list(PaymentApp.objects.filter(id__in=linked_app_ids).values("id", "name"))
    linked_app_names = {a["id"]: a["name"] for a in linked_apps}
    # Debit card: API returns linked bank balance for display
    if st_key == "DEBIT_CARD" and source.linked_bank_source_id and getattr(source, "linked_bank_source", None):
        display_balance = float(source.linked_bank_source.balance)
    else:
        display_balance = float(source.balance)
    return JsonResponse({
        "success": True,
        "data": {
            "id": str(source.id),
            "name": source.name,
            "type": BACKEND_TO_FRONTEND_SOURCE.get(st_key, "bank"),
            "sourceType": st_key,
            "bankName": source.bank_name or None,
            "balance": display_balance,
            "linkedAppIds": [str(aid) for aid in linked_app_ids],
            "linkedAppNames": [linked_app_names.get(aid, "") for aid in linked_app_ids],
            "linkedBankSourceId": str(source.linked_bank_source_id) if source.linked_bank_source_id else None,
            "linkedBankSourceName": source.linked_bank_source.name if source.linked_bank_source else None,
            "isActive": source.is_active,
            "createdAt": timezone.now().isoformat(),
        },
        "message": "Source created",
    }, status=201)


@jwt_auth_required
@require_http_methods(["GET", "PUT", "PATCH", "DELETE"])
def payment_source_detail(request, source_id):
    """Get, update, or delete a single payment source."""
    try:
        source = PaymentSource.objects.select_related(
            "linked_bank_source", "source_type"
        ).prefetch_related("app_links__payment_app").get(id=source_id, user=request.user)
    except PaymentSource.DoesNotExist:
        return JsonResponse({"success": False, "message": "Not found"}, status=404)

    def source_data(s):
        st_key = s.source_type.key if s.source_type_id else None
        linked_apps = list(s.app_links.all())
        app_ids = list({str(link.payment_app_id) for link in linked_apps if getattr(link, "payment_app_id", None)})
        app_names = list({link.payment_app.name for link in linked_apps if getattr(link, "payment_app", None)})
        # Debit card: show linked bank balance; others use source balance
        if st_key == "DEBIT_CARD" and getattr(s, "linked_bank_source", None):
            display_balance = float(s.linked_bank_source.balance)
        else:
            display_balance = float(s.balance)
        return {
            "id": str(s.id),
            "name": s.name,
            "type": BACKEND_TO_FRONTEND_SOURCE.get(st_key, "bank"),
            "sourceType": st_key,
            "bankName": s.bank_name or None,
            "balance": display_balance,
            "linkedAppIds": app_ids,
            "linkedAppNames": app_names,
            "linkedBankSourceId": str(s.linked_bank_source_id) if s.linked_bank_source_id else None,
            "linkedBankSourceName": s.linked_bank_source.name if s.linked_bank_source else None,
            "isActive": s.is_active,
            "createdAt": timezone.now().isoformat(),
        }

    if request.method == "GET":
        return JsonResponse({"success": True, "data": source_data(source)})

    if request.method in ("PUT", "PATCH"):
        try:
            body = json.loads(request.body)
        except json.JSONDecodeError:
            return JsonResponse({"success": False, "message": "Invalid JSON"}, status=400)
        if "name" in body and body["name"] is not None:
            name = str(body["name"]).strip()
            if name:
                source.name = name
        if "bankName" in body or "bank_name" in body:
            source.bank_name = (body.get("bankName") or body.get("bank_name") or "").strip()[:100]
        if "sourceType" in body or "source_type" in body:
            st_key = (body.get("sourceType") or body.get("source_type") or "").strip().upper()
            try:
                source.source_type = SourceType.objects.get(key=st_key)
            except SourceType.DoesNotExist:
                pass
        if "isActive" in body or "is_active" in body:
            source.is_active = bool(body.get("isActive", body.get("is_active")))
        if "linkedBankSourceId" in body or "linked_bank_source_id" in body:
            lid = body.get("linkedBankSourceId") or body.get("linked_bank_source_id")
            if lid is None or lid == "" or not str(lid).strip():
                source.linked_bank_source = None
            else:
                try:
                    linked = PaymentSource.objects.select_related("source_type").get(id=lid, user=request.user)
                    if linked.source_type.key == "BANK":
                        source.linked_bank_source = linked
                except (PaymentSource.DoesNotExist, ValueError):
                    pass
        if source.source_type.key == "DEBIT_CARD" and not source.linked_bank_source_id:
            return JsonResponse({"success": False, "message": "Debit card must have a linked bank account"}, status=400)
        source.save()
        return JsonResponse({
            "success": True,
            "data": source_data(source),
            "message": "Source updated",
        })

    if request.method == "DELETE":
        source.delete()
        return JsonResponse({"success": True, "message": "Source deleted"})

    return JsonResponse({"success": False, "message": "Method not allowed"}, status=405)


@jwt_auth_required
def transactions(request):
    """Return list of user's transactions with optional filters."""
    from django.db.models import Q

    qs = (
        Transaction.objects.filter(user=request.user)
        .select_related("payment_app_id", "payment_source_id", "payment_method_id")
        .prefetch_related("cashback_records", "source_cashback")
    )

    # Type filter: income / expense (query param is lowercase)
    type_param = (request.GET.get("type") or "").strip().upper()
    if type_param in ("INCOME", "EXPENSE"):
        qs = qs.filter(type=type_param)

    # Category
    category_param = (request.GET.get("category") or "").strip()
    if category_param:
        qs = qs.filter(category__iexact=category_param)

    # Search (description or category)
    search_param = (request.GET.get("search") or "").strip()
    if search_param:
        qs = qs.filter(
            Q(description__icontains=search_param) | Q(category__icontains=search_param)
        )

    # Date range (query params: dateFrom, dateTo as YYYY-MM-DD)
    date_from = request.GET.get("dateFrom", "").strip()
    date_to = request.GET.get("dateTo", "").strip()
    if date_from:
        try:
            from django.utils.dateparse import parse_date
            parsed = parse_date(date_from)
            if parsed:
                qs = qs.filter(timestamp__date__gte=parsed)
        except (ValueError, TypeError):
            pass
    if date_to:
        try:
            from django.utils.dateparse import parse_date
            parsed = parse_date(date_to)
            if parsed:
                qs = qs.filter(timestamp__date__lte=parsed)
        except (ValueError, TypeError):
            pass

    # Payment method type (frontend sends e.g. "upi" -> backend key "UPI")
    pm_type = (request.GET.get("paymentMethodType") or "").strip().lower()
    if pm_type and pm_type in FRONTEND_TO_BACKEND_METHOD:
        backend_key = FRONTEND_TO_BACKEND_METHOD[pm_type]
        qs = qs.filter(payment_method_id__key=backend_key)

    # Payment source id
    source_id = request.GET.get("paymentSourceId", "").strip()
    if source_id:
        try:
            qs = qs.filter(payment_source_id_id=int(source_id))
        except ValueError:
            pass

    # Sort (sortBy=date|amount, sortOrder=asc|desc)
    sort_by = (request.GET.get("sortBy") or "date").strip().lower()
    sort_order = (request.GET.get("sortOrder") or "desc").strip().lower()
    if sort_by == "amount":
        order_field = "amount" if sort_order == "asc" else "-amount"
    else:
        order_field = "timestamp" if sort_order == "asc" else "-timestamp"
    qs = qs.order_by(order_field)

    # Pagination
    try:
        limit = max(1, min(100, int(request.GET.get("limit", 20))))
    except ValueError:
        limit = 20
    try:
        page = max(1, int(request.GET.get("page", 1)))
    except ValueError:
        page = 1
    total = qs.count()
    offset = (page - 1) * limit
    page_qs = qs[offset : offset + limit]
    total_pages = (total + limit - 1) // limit if limit else 1

    now = timezone.now().isoformat()
    data = [_serialize_transaction(t, now) for t in page_qs]
    return JsonResponse({
        "success": True,
        "data": data,
        "pagination": {
            "page": page,
            "limit": limit,
            "total": total,
            "totalPages": total_pages,
        },
    })


def _apply_transaction_to_source_balance(source, amount, transaction_type, reverse=False):
    """
    Update payment source balance for a transaction.
    INCOME: add amount to source. EXPENSE: subtract amount from source.
    reverse=True undoes the effect (e.g. on update/delete).
    If the source is a DEBIT_CARD with a linked_bank_source, the same delta is applied to the
    linked bank account so the displayed balance (linked bank) stays in sync.
    Uses F() for atomic update. Swallows errors so transaction create/update is not rolled back.
    """
    if source is None:
        return
    try:
        amount = float(amount)
    except (TypeError, ValueError):
        return
    if amount == 0:
        return
    # Normalize to uppercase (frontend may send "expense")
    t = (transaction_type or "").strip().upper()
    if t not in ("INCOME", "EXPENSE"):
        return
    try:
        if t == "INCOME":
            delta = amount if not reverse else -amount
        else:
            # EXPENSE: subtract from balance
            delta = -amount if not reverse else amount
        PaymentSource.objects.filter(pk=source.pk).update(balance=F("balance") + delta)
        # Debit card: apply same delta to linked bank account (display balance comes from there)
        src = PaymentSource.objects.select_related("source_type", "linked_bank_source").filter(pk=source.pk).first()
        if src and getattr(getattr(src, "source_type", None), "key", None) == "DEBIT_CARD" and getattr(src, "linked_bank_source_id", None):
            bank = src.linked_bank_source
            if bank:
                PaymentSource.objects.filter(pk=bank.pk).update(balance=F("balance") + delta)
    except Exception as e:
        logger.exception("Failed to update payment source balance: %s", e)


def _create_single_cashback_entry(expense_transaction, entry, user):
    """Create one Cashback record from an entry dict. Returns the cashback amount (for cashback_received)."""
    kind = (entry.get("kind") or "fixed").strip().lower()
    if kind not in (Cashback.KIND_FIXED, Cashback.KIND_PERCENTAGE, Cashback.KIND_REWARD_POINTS):
        kind = Cashback.KIND_FIXED
    expense_amount = float(expense_transaction.amount)
    amount = 0
    percentage = None
    reward_points = None
    if kind == Cashback.KIND_FIXED:
        try:
            amount = float(entry.get("amount") or 0)
        except (TypeError, ValueError):
            amount = 0
    elif kind == Cashback.KIND_PERCENTAGE:
        try:
            percentage = float(entry.get("percentage") or 0)
            amount = round(expense_amount * percentage / 100, 2)
        except (TypeError, ValueError):
            percentage = 0
            amount = 0
    else:
        try:
            reward_points = int(entry.get("rewardPoints") or entry.get("reward_points") or 0)
        except (TypeError, ValueError):
            reward_points = 0

    credit_source = None
    credit_source_id_raw = entry.get("creditSourceId") or entry.get("credit_source_id")
    if credit_source_id_raw not in ("", None):
        try:
            credit_source = PaymentSource.objects.get(id=int(credit_source_id_raw), user=user)
        except (PaymentSource.DoesNotExist, ValueError, TypeError):
            pass

    reward_app = None
    reward_app_id_raw = entry.get("rewardAppId") or entry.get("reward_app_id")
    if reward_app_id_raw not in ("", None):
        try:
            reward_app = PaymentApp.objects.get(id=int(reward_app_id_raw), user=user)
        except (PaymentApp.DoesNotExist, ValueError, TypeError):
            pass

    # Reward points entry is only created when an app is selected
    if kind == Cashback.KIND_REWARD_POINTS and reward_app is None:
        return 0

    income_txn = None
    if kind in (Cashback.KIND_FIXED, Cashback.KIND_PERCENTAGE) and amount > 0 and credit_source is not None:
        desc = f"Cashback: {expense_transaction.description or 'Expense'}"
        income_txn = Transaction.objects.create(
            user=user,
            amount=amount,
            type="INCOME",
            category="cashback",
            description=desc[:500] if desc else "Cashback",
            notes="",
            payment_source_id=credit_source,
            payment_app_id=expense_transaction.payment_app_id,
            payment_method_id=expense_transaction.payment_method_id,
            timestamp=expense_transaction.timestamp,
        )
        # Only update credit source balance if it's different from expense's source (we already reduced expense source by cashback)
        if credit_source.pk != expense_transaction.payment_source_id_id:
            _apply_transaction_to_source_balance(credit_source, amount, "INCOME")

    Cashback.objects.create(
        transaction=expense_transaction,
        kind=kind,
        amount=amount,
        percentage=percentage,
        reward_points=reward_points,
        reward_app=reward_app,
        credit_source=credit_source,
        income_transaction=income_txn,
    )
    return amount


def _create_cashback_for_expense(expense_transaction, cashback_data, user):
    """
    Create Cashback record(s) for an expense. Supports both:
    - Single entry: cashback_data with enabled, kind, amount/percentage/rewardPoints, creditSourceId, rewardAppId.
    - Multiple entries: cashback_data.entries = [ { kind, ... }, ... ] so one txn can have cashback + reward points.
    Returns the total cashback amount (0 if none).
    """
    if not cashback_data:
        return 0
    entries = cashback_data.get("entries")
    if isinstance(entries, list) and len(entries) > 0:
        total_cashback = 0
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            total_cashback += _create_single_cashback_entry(expense_transaction, entry, user)
        if total_cashback > 0:
            expense_transaction.cashback_received = total_cashback
            expense_transaction.save(update_fields=["cashback_received"])
        return total_cashback
    if not cashback_data.get("enabled"):
        return 0
    amount = _create_single_cashback_entry(expense_transaction, cashback_data, user)
    if amount > 0:
        expense_transaction.cashback_received = amount
        expense_transaction.save(update_fields=["cashback_received"])
    return amount


def _serialize_transaction(t, now=None):
    """Serialize a Transaction for API response (list or detail)."""
    if now is None:
        now = timezone.now().isoformat()
    method_key = t.payment_method_id.key if t.payment_method_id else None
    out = {
        "id": str(t.id),
        "amount": float(t.amount),
        "type": (t.type or "").lower() if t.type else "expense",
        "category": t.category or "",
        "description": t.description or "",
        "notes": t.notes or "",
        "cashbackReceived": float(t.cashback_received) if t.cashback_received is not None else 0,
        "isAutomated": getattr(t, "is_automated", False),
        "method": method_key,
        "paymentMethodType": BACKEND_TO_FRONTEND_TYPE.get(method_key, "other") if method_key else None,
        "paymentMethodId": str(t.payment_method_id_id) if t.payment_method_id_id else None,
        "paymentMethodName": (t.payment_method_id.name if t.payment_method_id else None) or method_key,
        "sourceId": str(t.payment_source_id_id) if t.payment_source_id_id else None,
        "sourceName": t.payment_source_id.name if t.payment_source_id else None,
        "paymentSourceId": str(t.payment_source_id_id) if t.payment_source_id_id else None,
        "paymentSourceName": t.payment_source_id.name if t.payment_source_id else None,
        "paymentAppId": str(t.payment_app_id_id) if t.payment_app_id_id else None,
        "paymentAppName": t.payment_app_id.name if t.payment_app_id else None,
        "createdAt": t.timestamp.isoformat() if t.timestamp else now,
        "date": t.timestamp.isoformat() if t.timestamp else now,
    }
    # Attach cashback records for expense (list; one txn can have cashback + reward points)
    try:
        records = list(t.cashback_records.all())
    except AttributeError:
        records = []
    if records:
        out["cashback"] = [
            {
                "id": str(cb.id),
                "kind": cb.kind,
                "amount": float(cb.amount),
                "percentage": float(cb.percentage) if cb.percentage is not None else None,
                "rewardPoints": cb.reward_points,
                "creditSourceId": str(cb.credit_source_id) if cb.credit_source_id else None,
                "creditSourceName": cb.credit_source.name if cb.credit_source else None,
                "rewardAppId": str(cb.reward_app_id) if cb.reward_app_id else None,
                "rewardAppName": cb.reward_app.name if cb.reward_app else None,
                "incomeTransactionId": str(cb.income_transaction_id) if cb.income_transaction_id else None,
            }
            for cb in records
        ]
    else:
        out["cashback"] = []
    # If this INCOME is from cashback, attach source expense info
    try:
        source_cb = t.source_cashback.first() if hasattr(t, "source_cashback") else None
    except Exception:
        source_cb = None
    if source_cb is not None and source_cb.transaction_id:
        out["cashbackFromExpenseId"] = str(source_cb.transaction_id)
        out["cashbackFromDescription"] = source_cb.transaction.description or ""
    return out


@jwt_auth_required
@require_http_methods(["GET", "PUT", "PATCH", "DELETE"])
def transaction_detail(request, transaction_id):
    """Get, update, or delete a single transaction."""
    try:
        txn = Transaction.objects.filter(id=transaction_id, user=request.user).select_related(
            "payment_app_id", "payment_source_id", "payment_method_id"
        ).prefetch_related("cashback_records", "source_cashback").get()
    except Transaction.DoesNotExist:
        return JsonResponse({"success": False, "message": "Not found"}, status=404)

    if request.method == "GET":
        data = _serialize_transaction(txn)
        return JsonResponse({"success": True, "data": data})

    if request.method in ("PUT", "PATCH"):
        try:
            body = json.loads(request.body)
        except json.JSONDecodeError:
            return JsonResponse({"success": False, "message": "Invalid JSON"}, status=400)

        # Capture old values for balance reversal before applying body
        old_source = txn.payment_source_id
        old_amount = float(txn.amount)
        old_type = txn.type or "EXPENSE"
        old_cashback = float(txn.cashback_received or 0)

        amount = body.get("amount")
        if amount is not None:
            try:
                txn.amount = float(amount)
            except (TypeError, ValueError):
                return JsonResponse({"success": False, "message": "Invalid amount"}, status=400)

        type_raw = (body.get("type") or "").strip().upper()
        if type_raw in ("INCOME", "EXPENSE"):
            txn.type = type_raw

        if "category" in body and body["category"] is not None:
            txn.category = str(body["category"]).strip() or txn.category
        if "description" in body:
            txn.description = str(body["description"] or "").strip()
        if "notes" in body:
            txn.notes = str(body["notes"] or "").strip()
        if "cashbackReceived" in body or "cashback_received" in body:
            val = body.get("cashbackReceived") or body.get("cashback_received")
            try:
                txn.cashback_received = float(val) if val is not None else 0
            except (TypeError, ValueError):
                pass
        if "cashback" in body and isinstance(body.get("cashback"), (int, float)):
            try:
                txn.cashback_received = float(body["cashback"])
            except (TypeError, ValueError):
                pass
        if "isAutomated" in body or "is_automated" in body:
            txn.is_automated = bool(body.get("isAutomated", body.get("is_automated", False)))

        payment_app_id = body.get("paymentAppId")
        if "paymentAppId" in body:
            if payment_app_id == "" or payment_app_id is None:
                txn.payment_app_id = None
            else:
                try:
                    app = PaymentApp.objects.get(id=payment_app_id, user=request.user)
                    txn.payment_app_id = app
                except (PaymentApp.DoesNotExist, ValueError, TypeError):
                    pass

        payment_source_id_raw = body.get("paymentSourceId")
        if "paymentSourceId" in body:
            if payment_source_id_raw in ("", None):
                # Payment source is required for both income and expense; do not clear
                pass
            else:
                try:
                    source = PaymentSource.objects.get(id=int(payment_source_id_raw), user=request.user)
                    txn.payment_source_id = source
                except (PaymentSource.DoesNotExist, ValueError, TypeError):
                    return JsonResponse({"success": False, "message": "Invalid payment source"}, status=400)

        raw_payment_method_id = body.get("paymentMethodId")
        if "paymentMethodId" in body:
            if raw_payment_method_id in ("", None):
                txn.payment_method_id = None
            else:
                try:
                    pm = PaymentMethod.objects.get(id=int(raw_payment_method_id))
                    if pm.user_id is None or pm.user_id == request.user.id:
                        txn.payment_method_id = pm
                except (PaymentMethod.DoesNotExist, ValueError, TypeError):
                    pass

        if "date" in body and body["date"]:
            try:
                from django.utils.dateparse import parse_datetime
                parsed = parse_datetime(body["date"])
                if parsed:
                    if timezone.is_naive(parsed):
                        parsed = timezone.make_aware(parsed)
                    txn.timestamp = parsed
            except (ValueError, TypeError):
                pass

        if not txn.category:
            return JsonResponse({"success": False, "message": "Category is required"}, status=400)

        # Reverse previous balance effect on old source (net amount for expense)
        old_net = old_amount - (old_cashback if old_type == "EXPENSE" else 0)
        _apply_transaction_to_source_balance(old_source, old_net, old_type, reverse=True)
        txn.save()
        # Cashback (expense only): replace existing with body["cashback"] if it's an object (do before balance apply so txn.cashback_received is current)
        if txn.type == "EXPENSE" and "cashback" in body and isinstance(body.get("cashback"), dict):
            for existing in txn.cashback_records.all():
                if existing.income_transaction_id is not None:
                    inc = existing.income_transaction
                    if inc and inc.payment_source_id and inc.payment_source_id_id != txn.payment_source_id_id:
                        _apply_transaction_to_source_balance(
                            inc.payment_source_id, float(inc.amount), "INCOME", reverse=True
                        )
                    if inc:
                        inc.delete()
                existing.delete()
            _create_cashback_for_expense(txn, body["cashback"], request.user)
            entries = body["cashback"].get("entries")
            if isinstance(entries, list) and len(entries) == 0:
                txn.cashback_received = 0
                txn.save(update_fields=["cashback_received"])
        # Apply new balance effect (net amount for expense: amount - cashback)
        if txn.payment_source_id_id:
            new_net = float(txn.amount) - (float(txn.cashback_received or 0) if txn.type == "EXPENSE" else 0)
            _apply_transaction_to_source_balance(
                txn.payment_source_id, new_net, txn.type or "EXPENSE"
            )

        return JsonResponse({
            "success": True,
            "data": _serialize_transaction(txn),
            "message": "Transaction updated",
        })

    if request.method == "DELETE":
        # If expense has cashback records with income transactions, reverse and delete each income first
        for cb in txn.cashback_records.all():
            if cb.income_transaction_id is not None:
                inc = cb.income_transaction
                if inc and inc.payment_source_id and inc.payment_source_id_id != txn.payment_source_id_id:
                    _apply_transaction_to_source_balance(
                        inc.payment_source_id, float(inc.amount), "INCOME", reverse=True
                    )
                if inc:
                    inc.delete()
        # Reverse net expense from payment source (amount - cashback)
        net_expense = float(txn.amount) - float(txn.cashback_received or 0)
        _apply_transaction_to_source_balance(
            txn.payment_source_id, net_expense, txn.type or "EXPENSE", reverse=True
        )
        txn.delete()
        return JsonResponse({"success": True, "message": "Transaction deleted"})

    return JsonResponse({"success": False, "message": "Method not allowed"}, status=405)


@jwt_auth_required
@require_http_methods(["POST"])
def transaction_create(request):
    """Create a new transaction."""
    try:
        body = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"success": False, "message": "Invalid JSON"}, status=400)

    amount = body.get("amount")
    type_raw = (body.get("type") or "").strip().upper()
    category = (body.get("category") or "").strip()
    description = (body.get("description") or "").strip()
    notes = (body.get("notes") or "").strip()
    cashback_received = body.get("cashback_received")
    print("body", body)
    print("cashback_received", cashback_received)
    if cashback_received is None and isinstance(body.get("cashback"), (int, float)):
        cashback_received = body.get("cashback")
    if cashback_received is None:
        cashback_received = 0
    is_automated = body.get("isAutomated", False)

    # ForeignKey fields expect IDs (bigint), never empty string
    payment_app_id = body.get("paymentAppId")
    if payment_app_id == "" or payment_app_id is None:
        payment_app = None
    else:
        try:
            payment_app = PaymentApp.objects.get(id=payment_app_id, user=request.user)
        except (PaymentApp.DoesNotExist, ValueError, TypeError):
            payment_app = None

    payment_source = None
    payment_source_id_raw = body.get("paymentSourceId")
    if payment_source_id_raw in ("", None):
        return JsonResponse({"success": False, "message": "Payment source is required"}, status=400)
    try:
        payment_source_id = int(payment_source_id_raw) if payment_source_id_raw is not None else None
        if payment_source_id is None:
            raise ValueError("missing")
        payment_source = PaymentSource.objects.get(id=payment_source_id, user=request.user)
    except (PaymentSource.DoesNotExist, ValueError, TypeError):
        return JsonResponse({"success": False, "message": "Invalid payment source"}, status=400)

    # payment_method_id: optional for INCOME, required for EXPENSE (handled by frontend)
    raw_payment_method_id = body.get("paymentMethodId")
    payment_method = None
    if raw_payment_method_id not in ("", None):
        try:
            payment_method = PaymentMethod.objects.get(id=int(raw_payment_method_id))
            if payment_method.user_id is not None and payment_method.user_id != request.user.id:
                return JsonResponse({"success": False, "message": "Invalid payment method"}, status=400)
        except (PaymentMethod.DoesNotExist, ValueError, TypeError):
            return JsonResponse({"success": False, "message": "Invalid payment method"}, status=400)

    if not category:
        return JsonResponse({"success": False, "message": "Category is required"}, status=400)
    if amount is None:
        return JsonResponse({"success": False, "message": "Amount is required"}, status=400)
    try:
        amount = float(amount)
    except (TypeError, ValueError):
        return JsonResponse({"success": False, "message": "Invalid amount"}, status=400)
    if type_raw not in ("INCOME", "EXPENSE"):
        return JsonResponse({"success": False, "message": "Type must be INCOME or EXPENSE"}, status=400)

    create_kwargs = dict(
        user=request.user,
        amount=amount,
        type=type_raw,
        category=category,
        description=description,
        notes=notes,
        payment_app_id=payment_app,
        payment_source_id=payment_source,
        payment_method_id=payment_method,
        cashback_received=float(cashback_received) if cashback_received is not None else 0,
        is_automated=is_automated,
    )
    date_raw = body.get("date") or body.get("timestamp")
    if date_raw:
        try:
            from django.utils.dateparse import parse_datetime
            parsed = parse_datetime(date_raw) if isinstance(date_raw, str) else None
            if parsed:
                if timezone.is_naive(parsed):
                    parsed = timezone.make_aware(parsed)
                create_kwargs["timestamp"] = parsed
        except (ValueError, TypeError):
            pass
    transaction = Transaction.objects.create(**create_kwargs)
    if "timestamp" in create_kwargs:
        Transaction.objects.filter(pk=transaction.pk).update(timestamp=create_kwargs["timestamp"])
        transaction.timestamp = create_kwargs["timestamp"]
    # For expense: create cashback first so we know total; then debit source by (amount - cashback)
    net_expense = amount
    if type_raw == "EXPENSE":
        cashback_data = body.get("cashback")
        total_cashback = _create_cashback_for_expense(transaction, cashback_data, request.user) if cashback_data else 0
        net_expense = amount - total_cashback
    _apply_transaction_to_source_balance(payment_source, net_expense if type_raw == "EXPENSE" else amount, type_raw)

    return JsonResponse({"success": True, "message": "Transaction created", "data": {"id": str(transaction.id)}}, status=201)