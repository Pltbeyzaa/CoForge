from __future__ import annotations

from rest_framework import serializers

from .models import (
    DeveloperProfile,
    ProjectPost,
    ProjectRequiredSkill,
    Skill,
    UserSkill,
)


class DeveloperProfileSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(source="user.full_name", required=False, allow_blank=True)
    email = serializers.EmailField(source="user.email", read_only=True)
    skills = serializers.ListField(
        child=serializers.CharField(max_length=100),
        required=False,
        allow_empty=True,
    )

    class Meta:
        model = DeveloperProfile
        fields = (
            "id",
            "full_name",
            "email",
            "title",
            "bio",
            "github_url",
            "linkedin_url",
            "skills",
            "experience_level",
            "years_experience",
            "location",
            "is_open_to_projects",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["skills"] = [
            row.skill.name
            for row in instance.user_skills.select_related("skill").all()
            if row.skill_id and row.skill and row.skill.name
        ]
        return data

    def update(self, instance, validated_data):
        user_data = validated_data.pop("user", {})
        skills = validated_data.pop("skills", None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if "full_name" in user_data:
            safe_full_name = str(user_data.get("full_name") or "").strip()
            if instance.user.full_name != safe_full_name:
                instance.user.full_name = safe_full_name
                instance.user.save(update_fields=["full_name"])

        if skills is not None:
            normalized_names: list[str] = []
            seen: set[str] = set()
            for item in skills:
                raw_name = str(item or "").strip()
                if not raw_name:
                    continue
                key = raw_name.lower()
                if key in seen:
                    continue
                seen.add(key)
                normalized_names.append(raw_name)

            existing_rows = {
                row.skill.name.lower(): row
                for row in instance.user_skills.select_related("skill").all()
                if row.skill_id and row.skill and row.skill.name
            }
            keep_keys = set()
            for skill_name in normalized_names:
                key = skill_name.lower()
                keep_keys.add(key)
                if key in existing_rows:
                    continue
                skill_obj, _ = Skill.objects.get_or_create(name=skill_name)
                UserSkill.objects.create(profile=instance, skill=skill_obj)

            for key, row in existing_rows.items():
                if key not in keep_keys:
                    row.delete()

        return instance


class SkillSerializer(serializers.ModelSerializer):
    class Meta:
        model = Skill
        fields = ("id", "name", "category", "description", "created_at", "updated_at")
        read_only_fields = ("id", "created_at", "updated_at")


class UserSkillSerializer(serializers.ModelSerializer):
    skill = SkillSerializer(read_only=True)
    skill_id = serializers.PrimaryKeyRelatedField(
        queryset=Skill.objects.all(),
        source="skill",
        write_only=True,
    )

    class Meta:
        model = UserSkill
        fields = ("id", "skill", "skill_id", "level", "years_experience")
        read_only_fields = ("id", "skill")

    def create(self, validated_data):
        profile = self.context.get("profile")
        if profile is None:
            raise serializers.ValidationError({"detail": "profile context is required"})
        return UserSkill.objects.create(profile=profile, **validated_data)


class ProjectRequiredSkillNestedSerializer(serializers.Serializer):
    skill_id = serializers.PrimaryKeyRelatedField(queryset=Skill.objects.all(), source="skill")
    priority = serializers.IntegerField(default=1, min_value=1, max_value=255)


class ProjectPostSerializer(serializers.ModelSerializer):
    owner_email = serializers.EmailField(source="owner.email", read_only=True)
    required_skills = ProjectRequiredSkillNestedSerializer(many=True, required=False, write_only=True)

    class Meta:
        model = ProjectPost
        fields = (
            "id",
            "owner",
            "owner_email",
            "title",
            "description",
            "status",
            "max_team_size",
            "required_skills",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "owner", "owner_email", "created_at", "updated_at")

    def to_representation(self, instance):
        data = super().to_representation(instance)
        qs = instance.required_skills.select_related("skill").all()
        data["required_skills_detail"] = [
            {
                "skill_id": row.skill_id,
                "skill_name": row.skill.name,
                "priority": row.priority,
            }
            for row in qs
        ]
        return data

    def create(self, validated_data):
        skills_data = validated_data.pop("required_skills", [])
        owner = validated_data.pop("owner")
        post = ProjectPost.objects.create(owner=owner, **validated_data)
        for item in skills_data:
            ProjectRequiredSkill.objects.create(
                project=post,
                skill=item["skill"],
                priority=item.get("priority", 1),
            )
        return post

    def update(self, instance, validated_data):
        skills_data = validated_data.pop("required_skills", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if skills_data is not None:
            instance.required_skills.all().delete()
            for item in skills_data:
                ProjectRequiredSkill.objects.create(
                    project=instance,
                    skill=item["skill"],
                    priority=item.get("priority", 1),
                )
        return instance
