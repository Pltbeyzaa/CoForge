from __future__ import annotations

from rest_framework import permissions


class IsProjectOwner(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        return getattr(obj, "owner_id", None) == request.user.id


class IsOwnerOrReadOnly(permissions.BasePermission):
    """
    Nesne sahibi disinda kimse guncelleme / silme yapamaz.
    Okuma (GET) izinleri view seviyesinde (AllowAny vb.) ayrica verilir.
    """

    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        user = getattr(request, "user", None)
        if not user or not user.is_authenticated:
            return False
        return getattr(obj, "owner_id", None) == user.id
