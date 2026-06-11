from __future__ import annotations

from django.conf import settings
from django.db import models
from django.utils import timezone


class DeveloperProfile(models.Model):
    class ExperienceLevel(models.TextChoices):
        JUNIOR = "junior", "junior"
        MID = "mid", "mid"
        SENIOR = "senior", "senior"
        LEAD = "lead", "lead"

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="developer_profile",
    )
    title = models.CharField(max_length=255, blank=True)
    bio = models.TextField(blank=True)
    github_url = models.URLField(blank=True, null=True)
    linkedin_url = models.URLField(blank=True, null=True)
    experience_level = models.CharField(
        max_length=20,
        choices=ExperienceLevel.choices,
        blank=True,
        null=True,
    )
    years_experience = models.PositiveIntegerField(blank=True, null=True)
    location = models.CharField(max_length=255, blank=True)
    is_open_to_projects = models.BooleanField(default=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return f"DeveloperProfile({self.user_id})"


class Skill(models.Model):
    name = models.CharField(max_length=100, unique=True)
    category = models.CharField(max_length=100, blank=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return self.name


class UserSkill(models.Model):
    class Level(models.TextChoices):
        BEGINNER = "beginner", "beginner"
        INTERMEDIATE = "intermediate", "intermediate"
        ADVANCED = "advanced", "advanced"
        EXPERT = "expert", "expert"

    profile = models.ForeignKey(
        DeveloperProfile,
        on_delete=models.CASCADE,
        related_name="user_skills",
    )
    skill = models.ForeignKey(Skill, on_delete=models.CASCADE, related_name="user_skills")
    level = models.CharField(max_length=20, choices=Level.choices, blank=True, null=True)
    years_experience = models.PositiveIntegerField(blank=True, null=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["profile", "skill"], name="uniq_user_skill_profile_skill"),
        ]

    def __str__(self) -> str:
        return f"{self.profile_id}:{self.skill_id}"


class ProjectPost(models.Model):
    class Status(models.TextChoices):
        DRAFT = "draft", "draft"
        OPEN = "open", "open"
        MATCHING = "matching", "matching"
        IN_PROGRESS = "in_progress", "in_progress"
        COMPLETED = "completed", "completed"
        CANCELLED = "cancelled", "cancelled"

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="project_posts",
    )
    title = models.CharField(max_length=255)
    description = models.TextField()
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.OPEN,
    )
    max_team_size = models.PositiveIntegerField(blank=True, null=True)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return self.title


class ProjectRequiredSkill(models.Model):
    project = models.ForeignKey(
        ProjectPost,
        on_delete=models.CASCADE,
        related_name="required_skills",
    )
    skill = models.ForeignKey(Skill, on_delete=models.CASCADE, related_name="project_requirements")
    priority = models.PositiveSmallIntegerField(default=1)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["project", "skill"],
                name="uniq_project_required_skill",
            ),
        ]


class Team(models.Model):
    class Status(models.TextChoices):
        FORMING = "forming", "forming"
        ACTIVE = "active", "active"
        COMPLETED = "completed", "completed"
        CANCELLED = "cancelled", "cancelled"

    project = models.OneToOneField(
        ProjectPost,
        on_delete=models.CASCADE,
        related_name="team",
    )
    name = models.CharField(max_length=255, blank=True)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.FORMING,
    )
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)


class TeamMember(models.Model):
    class RoleInTeam(models.TextChoices):
        OWNER = "owner", "owner"
        DEVELOPER = "developer", "developer"
        SCRUM_MASTER = "scrum_master", "scrum_master"

    team = models.ForeignKey(Team, on_delete=models.CASCADE, related_name="members")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="team_memberships",
    )
    role_in_team = models.CharField(
        max_length=20,
        choices=RoleInTeam.choices,
        default=RoleInTeam.DEVELOPER,
    )
    joined_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["team", "user"], name="uniq_team_member"),
        ]


class Notification(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    type = models.CharField(max_length=100)
    payload = models.JSONField(blank=True, null=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=timezone.now)


class UserDailyLogin(models.Model):
    """Kullanicinin hangi gunlerde sisteme giris / aktivite gosterdigi (streak icin)."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="daily_logins",
    )
    login_date = models.DateField()
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "login_date"], name="uniq_user_daily_login_date"),
        ]

    def __str__(self) -> str:  # pragma: no cover
        return f"{self.user_id}:{self.login_date}"


class MatchSuggestion(models.Model):
    class Status(models.TextChoices):
        SUGGESTED = "suggested", "suggested"
        NOTIFIED = "notified", "notified"
        ACCEPTED = "accepted", "accepted"
        REJECTED = "rejected", "rejected"

    project = models.ForeignKey(
        ProjectPost,
        on_delete=models.CASCADE,
        related_name="match_suggestions",
    )
    developer_profile = models.ForeignKey(
        DeveloperProfile,
        on_delete=models.CASCADE,
        related_name="match_suggestions",
    )
    score = models.DecimalField(max_digits=5, decimal_places=2)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.SUGGESTED,
    )
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["project", "developer_profile"],
                name="uniq_match_suggestion",
            ),
        ]


class Evaluation(models.Model):
    project = models.ForeignKey(
        ProjectPost,
        on_delete=models.CASCADE,
        related_name="evaluations",
    )
    evaluator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="evaluations_given",
    )
    evaluatee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="evaluations_received",
    )
    rating_overall = models.PositiveSmallIntegerField(blank=True, null=True)
    rating_skill = models.PositiveSmallIntegerField(blank=True, null=True)
    rating_communication = models.PositiveSmallIntegerField(blank=True, null=True)
    comments = models.TextField(blank=True)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["project", "evaluator", "evaluatee"],
                name="uniq_evaluation_triplet",
            ),
        ]


class ProfileScore(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="profile_scores",
    )
    project = models.ForeignKey(
        ProjectPost,
        on_delete=models.CASCADE,
        related_name="profile_scores",
        blank=True,
        null=True,
    )
    success_score = models.DecimalField(max_digits=5, decimal_places=2)
    trust_score = models.DecimalField(max_digits=5, decimal_places=2)
    calculated_at = models.DateTimeField(default=timezone.now)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "project"],
                name="uniq_profile_score_user_project",
            ),
        ]


class EmbeddingMeta(models.Model):
    class EntityType(models.TextChoices):
        DEVELOPER_PROFILE = "developer_profile", "developer_profile"
        PROJECT_POST = "project_post", "project_post"

    entity_type = models.CharField(max_length=32, choices=EntityType.choices)
    entity_id = models.BigIntegerField()
    milvus_vector_id = models.BigIntegerField(blank=True, null=True)
    last_embedded_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["entity_type", "entity_id"],
                name="uniq_embedding_entity",
            ),
        ]
