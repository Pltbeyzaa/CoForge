from __future__ import annotations

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

User = get_user_model()


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    full_name = serializers.CharField(max_length=255)
    password = serializers.CharField(write_only=True, min_length=8)
    # Kayit formu: developer | founder | student (frontend) -> User.role
    role = serializers.CharField(required=False, allow_blank=True, max_length=32, default="")

    def validate_email(self, value: str) -> str:
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Bu e-posta adresi zaten kayitli.")
        return value

    def validate_role(self, value: str) -> str:
        raw = (value or "").strip().lower()
        mapping = {
            "developer": User.ROLE_DEVELOPER,
            "founder": User.ROLE_OWNER,
            "student": User.ROLE_DEVELOPER,
            "owner": User.ROLE_OWNER,
            "": User.ROLE_DEVELOPER,
        }
        return mapping.get(raw, User.ROLE_DEVELOPER)

    def validate_password(self, value: str) -> str:
        email = (getattr(self, "initial_data", None) or {}).get("email") or ""
        full_name = (getattr(self, "initial_data", None) or {}).get("full_name") or ""
        probe = User(email=email, full_name=full_name)
        try:
            validate_password(value, probe)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(list(exc.messages)) from exc
        return value

    def create(self, validated_data):
        role = validated_data.pop("role")
        email = validated_data["email"]
        full_name = validated_data["full_name"]
        password = validated_data["password"]
        return User.objects.create_user(
            email=email,
            full_name=full_name,
            password=password,
            role=role,
        )

