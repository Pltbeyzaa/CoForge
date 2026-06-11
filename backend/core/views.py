from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import permissions, status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import (
    DeveloperProfile,
    EmbeddingMeta,
    MatchSuggestion,
    ProjectPost,
    ProjectRequiredSkill,
    Skill,
    UserDailyLogin,
    UserSkill,
)
from .permissions import IsOwnerOrReadOnly
from .serializers import (
    DeveloperProfileSerializer,
    ProjectPostSerializer,
    SkillSerializer,
    UserSkillSerializer,
)
from .services.matchmaking_engine import get_projects_for_user, get_users_for_project
from .services.milvus_client import milvus_collections_snapshot, milvus_delete_project_embedding, milvus_health
from .services.nlp_service import (
    build_matchmaking_project_embedding_text,
    compute_embedding,
    extract_skill_tags,
    milvus_upsert_project_embedding,
    reindex_project_post_milvus,
)

MATCH_SCORE_STRONG_THRESHOLD = Decimal("70")


def _persist_discovery_match_suggestions(user, payload: dict) -> None:
    """Milvus sonucunu MatchSuggestion + ilan durumu ile senkronlar."""
    if not payload.get("ok"):
        return
    matches = payload.get("matches") or []
    if not matches:
        return
    dev_profile, _ = DeveloperProfile.objects.get_or_create(user=user)
    project_ids: list[int] = []
    for row in matches:
        pid = row.get("project_id")
        if pid is None:
            continue
        pid = int(pid)
        project_ids.append(pid)
        score_val = row.get("similarity_percent")
        if score_val is None:
            score_val = row.get("score", 0)
        try:
            dec = Decimal(str(score_val)).quantize(Decimal("0.01"))
        except Exception:
            dec = Decimal("0")
        project = ProjectPost.objects.filter(pk=pid).exclude(owner=user).first()
        if not project:
            continue
        MatchSuggestion.objects.update_or_create(
            project=project,
            developer_profile=dev_profile,
            defaults={
                "score": dec,
                "status": MatchSuggestion.Status.SUGGESTED,
            },
        )
    if project_ids:
        ProjectPost.objects.filter(id__in=project_ids, status=ProjectPost.Status.OPEN).update(
            status=ProjectPost.Status.MATCHING
        )


def _record_user_active_day(user) -> None:
    today = timezone.localdate()
    UserDailyLogin.objects.get_or_create(user=user, login_date=today)


def _compute_login_streak(user) -> int:
    """Bugunden geriye dogru ard arda aktivite gunu sayisi (bugun kayitli degilse 0)."""
    today = timezone.localdate()
    dates = set(UserDailyLogin.objects.filter(user=user).values_list("login_date", flat=True))
    streak = 0
    d = today
    while d in dates:
        streak += 1
        d -= timedelta(days=1)
    return streak


class MeStatsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        _record_user_active_day(request.user)
        dev_profile, _ = DeveloperProfile.objects.get_or_create(user=request.user)

        completed_projects = ProjectPost.objects.filter(
            owner=request.user,
            status=ProjectPost.Status.COMPLETED,
        ).count()

        total_matches = MatchSuggestion.objects.filter(
            developer_profile=dev_profile,
            score__gte=MATCH_SCORE_STRONG_THRESHOLD,
        ).count()

        streak_days = _compute_login_streak(request.user)

        return Response(
            {
                "completed_projects": completed_projects,
                "total_matches": total_matches,
                "streak_days": streak_days,
            }
        )


class MeProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile, _ = DeveloperProfile.objects.get_or_create(user=request.user)
        return Response(DeveloperProfileSerializer(profile).data)

    def patch(self, request):
        profile, _ = DeveloperProfile.objects.get_or_create(user=request.user)
        serializer = DeveloperProfileSerializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class MeUserSkillListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile, _ = DeveloperProfile.objects.get_or_create(user=request.user)
        qs = profile.user_skills.select_related("skill")
        return Response(UserSkillSerializer(qs, many=True).data)

    def post(self, request):
        profile, _ = DeveloperProfile.objects.get_or_create(user=request.user)
        serializer = UserSkillSerializer(data=request.data, context={"profile": profile})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(UserSkillSerializer(serializer.instance).data, status=status.HTTP_201_CREATED)


class MeUserSkillDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, pk):
        profile, _ = DeveloperProfile.objects.get_or_create(user=request.user)
        row = get_object_or_404(UserSkill, pk=pk, profile=profile)
        row.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class SkillViewSet(viewsets.ModelViewSet):
    queryset = Skill.objects.all().order_by("name")
    serializer_class = SkillSerializer
    permission_classes = [permissions.IsAuthenticated]


class ProjectPostViewSet(viewsets.ModelViewSet):
    queryset = (
        ProjectPost.objects.select_related("owner")
        .prefetch_related("required_skills__skill")
        .order_by("-created_at")
    )
    serializer_class = ProjectPostSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_permissions(self):
        # Herkese acik ilan panosu: tum kayitli ilanlar listelenir / detay okunur
        if self.action in ("list", "retrieve"):
            return [permissions.AllowAny()]
        if self.action in ("update", "partial_update", "destroy"):
            return [permissions.IsAuthenticated(), IsOwnerOrReadOnly()]
        return [permissions.IsAuthenticated()]

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    @staticmethod
    def _validated_affects_embedding(serializer: ProjectPostSerializer) -> bool:
        keys = set(serializer.validated_data.keys())
        return bool(keys.intersection({"title", "description", "required_skills"}))

    def perform_update(self, serializer):
        instance = serializer.save()
        if self._validated_affects_embedding(serializer):
            fresh = (
                ProjectPost.objects.prefetch_related("required_skills__skill")
                .select_related("owner")
                .get(pk=instance.pk)
            )
            reindex_project_post_milvus(fresh)

    def perform_destroy(self, instance):
        pk = instance.pk
        EmbeddingMeta.objects.filter(
            entity_type=EmbeddingMeta.EntityType.PROJECT_POST,
            entity_id=pk,
        ).delete()
        milvus_delete_project_embedding(project_id=pk)
        instance.delete()


class MilvusHealthView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        payload = milvus_health()
        payload["collections"] = milvus_collections_snapshot()
        return Response(payload)


class ExtractTagsView(APIView):
    """
    Serbest metinden yetkinlik/teknoloji tag'leri cikarir.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        text = request.data.get("text", "")
        max_tags = int(request.data.get("max_tags", 10))
        tags = extract_skill_tags(text, max_tags=max_tags)
        return Response({"ok": True, "tags": tags})


class ProjectAnalyzeView(APIView):
    """
    Proje aciklamasindan NLP ile tag cikarir, required_skills'i gunceller ve Milvus'a embedding yazar.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk: int):
        project = get_object_or_404(ProjectPost, pk=pk, owner=request.user)

        max_tags = int(request.data.get("max_tags", 10))
        tags = extract_skill_tags(project.description, max_tags=max_tags)

        # required_skills'i yenile
        ProjectRequiredSkill.objects.filter(project=project).delete()
        required_rows: list[ProjectRequiredSkill] = []
        for tag in tags:
            skill, _ = Skill.objects.get_or_create(name=tag)
            required_rows.append(ProjectRequiredSkill(project=project, skill=skill, priority=1))
        ProjectRequiredSkill.objects.bulk_create(required_rows)

        # Embedding (aciklama + tagler)
        # Milvus down ise (Risk-1 B plan) embedding'i su anda atlayip sadece MySQL tarafini ilerletelim.
        milvus_health_status = milvus_health()
        if milvus_health_status.get("ok"):
            text_for_embedding = build_matchmaking_project_embedding_text(
                project.title or "",
                project.description or "",
                tags,
            )
            embedding = compute_embedding(text_for_embedding)
            milvus_result = milvus_upsert_project_embedding(project_id=project.id, embedding=embedding)
        else:
            milvus_result = {
                "ok": False,
                "skipped": True,
                "reason": "Milvus is not reachable/healthy from backend (B plan: keyword/MySQL matching).",
                "health": milvus_health_status,
            }

        # Embedding meta
        if milvus_result.get("ok"):
            EmbeddingMeta.objects.update_or_create(
                entity_type=EmbeddingMeta.EntityType.PROJECT_POST,
                entity_id=project.id,
                defaults={
                    "milvus_vector_id": project.id,
                    "last_embedded_at": timezone.now(),
                },
            )

        return Response(
            {
                "ok": True,
                "project_id": project.id,
                "tags": tags,
                "required_skills_count": len(required_rows),
                "milvus": milvus_result,
            }
        )

class MeMatchSuggestionsView(APIView):
    """
    Eşleşme: TF-IDF Cosine Similarity ile kullanıcıya uygun açık ilanlar.
    GET/POST: get_projects_for_user; sonuçlar MatchSuggestion tablosuyla senkronlanır.
    """

    permission_classes = [permissions.IsAuthenticated]

    def _run(self, request, top_k: int):
        try:
            payload = get_projects_for_user(user=request.user, top_k=top_k)
            if payload.get("ok"):
                _persist_discovery_match_suggestions(request.user, payload)
            status_code = 200 if payload.get("ok") else 503
            return Response(payload, status=status_code)
        except Exception as e:
            print(f"CRITICAL API ERROR (match-suggestions): {e}")
            import traceback
            traceback.print_exc()
            return Response({"ok": True, "matches": [], "source": "error_fallback"}, status=200)

    def get(self, request):
        top_k = int(request.query_params.get("top_k", 10))
        return self._run(request, top_k)

    def post(self, request):
        top_k = int(request.data.get("top_k", 10))
        return self._run(request, top_k)


class ProjectCandidateSuggestionsView(APIView):
    """
    Recruitment mode: Ilan sahibine uygun adaylari onerir.
    """

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk: int):
        top_k = int(request.query_params.get("top_k", 8))
        project = get_object_or_404(ProjectPost.objects.prefetch_related("required_skills__skill"), pk=pk, owner=request.user)
        return Response(get_users_for_project(project=project, top_k=top_k))
