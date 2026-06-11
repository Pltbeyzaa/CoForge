"""
TF-IDF Cosine Similarity tabanlı eşleştirme motoru.

Kullanıcı metni  : kullanıcının yetenekleri (skill isimleri) + unvan + biyografi
Proje metni      : projenin gereken yetenekleri + başlık + açıklama

sklearn TfidfVectorizer ile iki metin seti arasındaki benzerlik
cosine_similarity ile hesaplanır; skor 0-100 aralığına çevrilir.
Skor >= 25 olanlar listeye alınır, azalan sıraya göre döndürülür.
"""

from __future__ import annotations

import logging
from typing import Any

from django.contrib.auth import get_user_model

from ..models import DeveloperProfile, ProjectPost, UserSkill

User = get_user_model()
logger = logging.getLogger(__name__)

_SCORE_THRESHOLD = 25


# ---------------------------------------------------------------------------
# Metin oluşturucular
# ---------------------------------------------------------------------------

def _user_text(user: Any) -> str:
    """Kullanıcının yetenekleri + unvan + biyografisini tek string'e dönüştürür."""
    try:
        profile = (
            DeveloperProfile.objects
            .prefetch_related("user_skills__skill")
            .get(user=user)
        )
    except DeveloperProfile.DoesNotExist:
        return "developer"

    title = profile.title or ""
    bio = profile.bio or ""
    skills = list(
        UserSkill.objects
        .filter(profile=profile)
        .select_related("skill")
        .values_list("skill__name", flat=True)
    )
    skill_text = " ".join(skills)
    result = " ".join(filter(None, [title, skill_text, bio])).strip()
    return result or "developer"


def _project_text(project: ProjectPost) -> str:
    """Projenin gereken yetenekleri + başlık + açıklamasını tek string'e dönüştürür."""
    title = project.title or ""
    description = project.description or ""
    req_skills = list(
        project.required_skills
        .select_related("skill")
        .values_list("skill__name", flat=True)
    )
    skill_text = " ".join(req_skills)
    result = " ".join(filter(None, [title, skill_text, description])).strip()
    return result or "project"


def _match_level(score: float) -> str:
    if score >= 70:
        return "high"
    if score >= 45:
        return "mid"
    return "low"


# ---------------------------------------------------------------------------
# Kullanıcı → Projeler eşleştirmesi
# ---------------------------------------------------------------------------

def get_projects_for_user(user: Any, top_k: int = 10) -> dict[str, Any]:
    """
    TF-IDF cosine similarity ile kullanıcıya uygun OPEN projeleri döndürür.

    Dönen payload yapısı:
    {
        "ok": True,
        "source": "tfidf",
        "matches": [
            {
                "project_id": int,
                "project_title": str,
                "project_description": str,   # ilk 200 karakter
                "status": str,
                "owner_name": str,
                "required_skills": [str, ...],
                "match_score": float,          # 0-100
                "similarity_percent": float,   # match_score ile aynı (persist uyumluluğu)
                "match_level": "high"|"mid"|"low",
            },
            ...
        ],
        "dropped_low_match_count": int,
    }
    """
    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.metrics.pairwise import cosine_similarity
    except ImportError:
        logger.error("scikit-learn kurulu değil. Çalıştır: pip install scikit-learn")
        return {
            "ok": False,
            "source": "tfidf_unavailable",
            "error": "scikit-learn is not installed",
            "matches": [],
            "dropped_low_match_count": 0,
        }

    # OPEN projeler (sahibin kendi ilanları hariç)
    open_projects = list(
        ProjectPost.objects
        .filter(status=ProjectPost.Status.OPEN)
        .exclude(owner=user)
        .prefetch_related("required_skills__skill")
        .select_related("owner")
    )

    print(f"[MATCH DEBUG] user={user.email} | open_projects={len(open_projects)}")

    if not open_projects:
        print(f"[MATCH DEBUG] Hiç OPEN proje yok → boş döndürülüyor.")
        return {
            "ok": True,
            "source": "tfidf",
            "matches": [],
            "dropped_low_match_count": 0,
        }

    # Kullanıcı yeteneklerini al (debug için)
    user_skill_names = set(
        UserSkill.objects
        .filter(profile__user=user)
        .select_related("skill")
        .values_list("skill__name", flat=True)
    )
    user_skill_names_lower = {s.lower() for s in user_skill_names}
    print(f"[MATCH DEBUG] user_skills={list(user_skill_names) or '(boş)'}")

    user_doc = _user_text(user)
    project_docs = [_project_text(p) for p in open_projects]

    print(f"[MATCH DEBUG] user_doc={repr(user_doc[:120])}")

    # TF-IDF matris: satır 0 = kullanıcı, 1..n = projeler
    vectorizer = TfidfVectorizer(
        analyzer="word",
        ngram_range=(1, 2),
        min_df=1,
        lowercase=True,
    )
    tfidf_matrix = vectorizer.fit_transform([user_doc] + project_docs)
    similarities = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:])[0]

    def _build_match_row(project: ProjectPost, score: float) -> dict[str, Any]:
        req_skills = list(
            project.required_skills
            .select_related("skill")
            .values_list("skill__name", flat=True)
        )
        owner_name = getattr(project.owner, "full_name", None) or project.owner.email
        return {
            "project_id": project.id,
            "project_title": project.title,
            "project_description": (project.description or "")[:200],
            "status": project.status,
            "owner_name": owner_name,
            "required_skills": req_skills,
            "match_score": score,
            "similarity_percent": score,
            "match_level": _match_level(score),
        }

    matches: list[dict[str, Any]] = []
    dropped = 0

    for i, project in enumerate(open_projects):
        score = round(float(similarities[i]) * 100, 1)
        req_skills_lower = {
            s.lower() for s in
            project.required_skills.select_related("skill").values_list("skill__name", flat=True)
        }
        shared = user_skill_names_lower & req_skills_lower
        print(
            f"[MATCH DEBUG] proje='{project.title[:40]}' "
            f"tfidf={score} shared_skills={shared or '(yok)'}"
        )

        # Kabul: TF-IDF eşiği VEYA en az 1 ortak yetenek
        if score >= _SCORE_THRESHOLD or shared:
            effective_score = score if score >= _SCORE_THRESHOLD else max(score, 5.0)
            matches.append(_build_match_row(project, effective_score))
        else:
            dropped += 1

    matches.sort(key=lambda x: x["match_score"], reverse=True)
    matches = matches[:top_k]

    # --- FALLBACK: TF-IDF + skill intersection da 0 sonuç verdiyse rastgele 5 OPEN ilan ---
    source = "tfidf"
    if not matches:
        print(f"[MATCH DEBUG] TF-IDF + skill eşleşmesi yok → rastgele 5 OPEN ilan fallback devreye giriyor.")
        fallback_projects = list(
            ProjectPost.objects
            .filter(status=ProjectPost.Status.OPEN)
            .exclude(owner=user)
            .prefetch_related("required_skills__skill")
            .select_related("owner")
            .order_by("?")[:5]
        )
        for p in fallback_projects:
            matches.append(_build_match_row(p, 1.0))
        source = "fallback_random"
        dropped = max(0, dropped - len(matches))

    print(
        f"[MATCH DEBUG] SONUÇ: source={source} returned={len(matches)} dropped={dropped}"
    )

    logger.info(
        "get_projects_for_user(%s): user_id=%s candidates=%s returned=%s dropped=%s",
        source,
        user.pk,
        len(open_projects),
        len(matches),
        dropped,
    )

    return {
        "ok": True,
        "source": source,
        "matches": matches,
        "dropped_low_match_count": dropped,
    }


# ---------------------------------------------------------------------------
# Proje → Geliştiriciler eşleştirmesi
# ---------------------------------------------------------------------------

def get_users_for_project(project: ProjectPost, top_k: int = 10) -> dict[str, Any]:
    """
    TF-IDF cosine similarity ile projeye uygun geliştiricileri döndürür.

    Dönen payload yapısı:
    {
        "ok": True,
        "source": "tfidf",
        "project_id": int,
        "matches": [
            {
                "developer_profile_id": int,
                "user_id": int,
                "full_name": str,
                "email": str,
                "title": str,
                "bio": str,
                "skills": [str, ...],
                "match_score": float,
                "similarity_percent": float,
                "match_level": "high"|"mid"|"low",
            },
            ...
        ],
        "dropped_low_match_count": int,
    }
    """
    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.metrics.pairwise import cosine_similarity
    except ImportError:
        logger.error("scikit-learn kurulu değil. Çalıştır: pip install scikit-learn")
        return {
            "ok": False,
            "source": "tfidf_unavailable",
            "error": "scikit-learn is not installed",
            "project_id": project.id,
            "matches": [],
            "dropped_low_match_count": 0,
        }

    profiles = list(
        DeveloperProfile.objects
        .select_related("user")
        .prefetch_related("user_skills__skill")
        .exclude(user=project.owner)
    )

    if not profiles:
        return {
            "ok": True,
            "source": "tfidf",
            "project_id": project.id,
            "matches": [],
            "dropped_low_match_count": 0,
        }

    project_doc = _project_text(project)

    def _profile_doc(dp: DeveloperProfile) -> str:
        title = dp.title or ""
        bio = dp.bio or ""
        skills = list(
            dp.user_skills
            .select_related("skill")
            .values_list("skill__name", flat=True)
        )
        skill_text = " ".join(skills)
        return " ".join(filter(None, [title, skill_text, bio])).strip() or "developer"

    profile_docs = [_profile_doc(dp) for dp in profiles]

    vectorizer = TfidfVectorizer(
        analyzer="word",
        ngram_range=(1, 2),
        min_df=1,
        lowercase=True,
    )
    tfidf_matrix = vectorizer.fit_transform([project_doc] + profile_docs)
    similarities = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:])[0]

    matches: list[dict[str, Any]] = []
    dropped = 0

    for i, dp in enumerate(profiles):
        score = round(float(similarities[i]) * 100, 1)

        if score < _SCORE_THRESHOLD:
            dropped += 1
            continue

        skills = list(
            dp.user_skills
            .select_related("skill")
            .values_list("skill__name", flat=True)
        )
        full_name = (
            getattr(dp.user, "full_name", None)
            or dp.user.email
        )

        matches.append({
            "developer_profile_id": dp.id,
            "user_id": dp.user_id,
            "full_name": full_name,
            "email": dp.user.email,
            "title": dp.title or "",
            "bio": (dp.bio or "")[:150],
            "skills": skills,
            "match_score": score,
            "similarity_percent": score,
            "match_level": _match_level(score),
        })

    matches.sort(key=lambda x: x["match_score"], reverse=True)
    matches = matches[:top_k]

    logger.info(
        "get_users_for_project(tfidf): project_id=%s candidates=%s returned=%s dropped=%s",
        project.id,
        len(profiles),
        len(matches),
        dropped,
    )

    return {
        "ok": True,
        "source": "tfidf",
        "project_id": project.id,
        "matches": matches,
        "dropped_low_match_count": dropped,
    }
