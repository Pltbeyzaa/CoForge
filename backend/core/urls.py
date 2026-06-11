from __future__ import annotations

from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    MeProfileView,
    MeStatsView,
    MeUserSkillDetailView,
    MeUserSkillListView,
    MeMatchSuggestionsView,
    ProjectCandidateSuggestionsView,
    MilvusHealthView,
    ExtractTagsView,
    ProjectAnalyzeView,
    ProjectPostViewSet,
    SkillViewSet,
)

# --- DOĞRU ADRESTEN IMPORT EDİLEN OTONOM SCRUM MASTER ---
from accounts.views import ScrumMasterChatView

router = DefaultRouter()
router.register("skills", SkillViewSet, basename="skill")
router.register("project-posts", ProjectPostViewSet, basename="project-post")

project_post_detail_alias = ProjectPostViewSet.as_view(
    {
        "get": "retrieve",
        "put": "update",
        "patch": "partial_update",
        "delete": "destroy",
    }
)

urlpatterns = [
    path("me/stats/", MeStatsView.as_view(), name="me_stats"),
    path("me/profile/", MeProfileView.as_view(), name="me_profile"),
    path("me/skills/", MeUserSkillListView.as_view(), name="me_skills"),
    path("me/skills/<int:pk>/", MeUserSkillDetailView.as_view(), name="me_skill_detail"),
    path("me/match-suggestions/", MeMatchSuggestionsView.as_view(), name="me_match_suggestions"),
    path("project-posts/<int:pk>/candidate-suggestions/", ProjectCandidateSuggestionsView.as_view(), name="project_candidate_suggestions"),
    path("health/milvus/", MilvusHealthView.as_view(), name="health_milvus"),
    path("nlp/extract-tags/", ExtractTagsView.as_view(), name="nlp_extract_tags"),
    path("project-posts/<int:pk>/analyze/", ProjectAnalyzeView.as_view(), name="project_analyze"),
    path("projects/<int:pk>/", project_post_detail_alias, name="project_post_detail_alias"),
    
    # --- YENİ EKLENEN OTONOM SCRUM MASTER ROTASI ---
    path("scrum-master/chat/", ScrumMasterChatView.as_view(), name="scrum-master-chat"),
    
    path("", include(router.urls)),
]