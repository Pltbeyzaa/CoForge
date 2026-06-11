from __future__ import annotations

import logging

from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from .models import DeveloperProfile, ProjectPost, ProjectRequiredSkill, UserSkill
from .services.milvus_client import milvus_health
from .services.nlp_service import upsert_developer_profile_milvus, upsert_project_post_milvus

logger = logging.getLogger(__name__)


def _milvus_ready() -> bool:
    return bool(milvus_health().get("ok"))


@receiver(post_save, sender=DeveloperProfile)
def developer_profile_saved_update_milvus(sender, instance: DeveloperProfile, **kwargs) -> None:
    if not _milvus_ready():
        return
    try:
        upsert_developer_profile_milvus(instance)
    except Exception as exc:  # pragma: no cover
        logger.warning("Milvus user upsert (DeveloperProfile save) failed: %s", exc)


@receiver(post_save, sender=ProjectPost)
def project_post_saved_update_milvus(sender, instance: ProjectPost, **kwargs) -> None:
    if not _milvus_ready():
        return
    try:
        upsert_project_post_milvus(instance)
    except Exception as exc:  # pragma: no cover
        logger.warning("Milvus project upsert (ProjectPost save) failed: %s", exc)


@receiver(post_save, sender=UserSkill)
@receiver(post_delete, sender=UserSkill)
def user_skill_changed_update_milvus(sender, instance: UserSkill, **kwargs) -> None:
    if not _milvus_ready():
        return
    try:
        profile = DeveloperProfile.objects.select_related("user").prefetch_related("user_skills__skill").get(
            pk=instance.profile_id
        )
    except DeveloperProfile.DoesNotExist:
        return
    try:
        upsert_developer_profile_milvus(profile)
    except Exception as exc:  # pragma: no cover
        logger.warning("Milvus user upsert (UserSkill change) failed: %s", exc)


@receiver(post_save, sender=ProjectRequiredSkill)
@receiver(post_delete, sender=ProjectRequiredSkill)
def project_required_skill_changed_update_milvus(sender, instance: ProjectRequiredSkill, **kwargs) -> None:
    if not _milvus_ready():
        return
    try:
        project = ProjectPost.objects.prefetch_related("required_skills__skill").get(pk=instance.project_id)
    except ProjectPost.DoesNotExist:
        return
    try:
        upsert_project_post_milvus(project)
    except Exception as exc:  # pragma: no cover
        logger.warning("Milvus project upsert (ProjectRequiredSkill change) failed: %s", exc)
