from __future__ import annotations

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from core.models import UserDailyLogin
from .serializers import RegisterSerializer

# --- YENI EKLENEN IMPORT (Scrum Master AI Servisi) ---
from .scrum_service import chat_with_scrum_master
User = get_user_model()


class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        UserDailyLogin.objects.get_or_create(user=user, login_date=timezone.localdate())

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": {"id": user.id, "email": user.email, "full_name": user.full_name, "role": user.role},
            },
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        email = request.data.get("email")
        password = request.data.get("password")
        if not email or not password:
            return Response({"detail": "email and password are required"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({"detail": "Invalid credentials"}, status=status.HTTP_401_UNAUTHORIZED)

        if not user.check_password(password):
            return Response({"detail": "Invalid credentials"}, status=status.HTTP_401_UNAUTHORIZED)

        refresh = RefreshToken.for_user(user)
        UserDailyLogin.objects.get_or_create(user=user, login_date=timezone.localdate())
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": {"id": user.id, "email": user.email, "full_name": user.full_name, "role": user.role},
            },
            status=status.HTTP_200_OK,
        )


# --- YENI EKLENEN OTONOM SCRUM MASTER KAPISI ---
class ScrumMasterChatView(APIView):
    # Testleri rahat yapabilmen için şimdilik AllowAny bıraktım.
    # Canlıya alırken [permissions.IsAuthenticated] yapabilirsin.
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        project_title = request.data.get("project_title")
        project_description = request.data.get("project_description")
        team_members = request.data.get("team_members", [])
        user_message = request.data.get("user_message")

        if not all([project_title, project_description, user_message]):
            return Response(
                {"error": "Lütfen proje adı, açıklaması ve mesajınızı eksiksiz gönderin."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Yapay zeka servisimizi cagiriyoruz
        ai_response = chat_with_scrum_master(
            project_title=project_title,
            project_description=project_description,
            team_members=team_members,
            user_message=user_message
        )

        if "error" in ai_response:
            return Response(ai_response, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        return Response(ai_response, status=status.HTTP_200_OK)