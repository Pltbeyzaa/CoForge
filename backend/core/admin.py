from django.contrib import admin

from .models import (
    DeveloperProfile,
    EmbeddingMeta,
    Evaluation,
    MatchSuggestion,
    Notification,
    ProfileScore,
    ProjectPost,
    ProjectRequiredSkill,
    Skill,
    Team,
    TeamMember,
    UserDailyLogin,
    UserSkill,
)


@admin.register(DeveloperProfile)
class DeveloperProfileAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "title", "experience_level", "is_open_to_projects")


@admin.register(Skill)
class SkillAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "category")
    search_fields = ("name",)


@admin.register(UserSkill)
class UserSkillAdmin(admin.ModelAdmin):
    list_display = ("id", "profile", "skill", "level")


@admin.register(UserDailyLogin)
class UserDailyLoginAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "login_date", "created_at")
    list_filter = ("login_date",)


@admin.register(ProjectPost)
class ProjectPostAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "owner", "status", "created_at")
    list_filter = ("status",)


@admin.register(ProjectRequiredSkill)
class ProjectRequiredSkillAdmin(admin.ModelAdmin):
    list_display = ("id", "project", "skill", "priority")


@admin.register(Team)
class TeamAdmin(admin.ModelAdmin):
    list_display = ("id", "project", "name", "status")


@admin.register(TeamMember)
class TeamMemberAdmin(admin.ModelAdmin):
    list_display = ("id", "team", "user", "role_in_team")


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "type", "is_read", "created_at")


@admin.register(MatchSuggestion)
class MatchSuggestionAdmin(admin.ModelAdmin):
    list_display = ("id", "project", "developer_profile", "score", "status")


@admin.register(Evaluation)
class EvaluationAdmin(admin.ModelAdmin):
    list_display = ("id", "project", "evaluator", "evaluatee", "created_at")


@admin.register(ProfileScore)
class ProfileScoreAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "project", "success_score", "trust_score")


@admin.register(EmbeddingMeta)
class EmbeddingMetaAdmin(admin.ModelAdmin):
    list_display = ("id", "entity_type", "entity_id", "milvus_vector_id")
