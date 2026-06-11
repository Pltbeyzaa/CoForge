from __future__ import annotations

import hashlib
import json
import logging
import os
import re
from typing import Any

from django.utils import timezone

logger = logging.getLogger(__name__)


def _get_embedding_config() -> dict[str, Any]:
    return {
        "model": os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small"),
        "dim": int(os.getenv("OPENAI_EMBEDDING_DIM", "1536")),
    }


def _heuristic_skill_tags(text: str, max_tags: int = 10) -> list[str]:
    """
    OpenAI key yoksa bile demo calissin diye basit keyword tabanli cikarim.
    """
    keywords = [
        "python",
        "django",
        "djangorestframework",
        "drf",
        "javascript",
        "typescript",
        "react",
        "react native",
        "flutter",
        "next.js",
        "node",
        "docker",
        "nginx",
        "gunicorn",
        "mysql",
        "milvus",
        "openai",
        "spacy",
        "nlp",
        "ml",
        "machine learning",
        "rest",
        "api",
        "graphql",
        "postgres",
        "redis",
        "celery",
        "kubernetes",
        "aws",
        "gcp",
        "azure",
    ]

    lower = text.lower()
    # Kelimeyi eslestirmek icin kucuk/ buyuk duyarliligi yok.
    found: list[str] = []
    for k in keywords:
        if k in lower:
            pretty = k.replace("djangorestframework", "Django REST Framework")
            pretty = pretty.replace("react native", "React Native")
            pretty = pretty.replace("machine learning", "Machine Learning")
            pretty = pretty.replace("nlp", "NLP")
            pretty = pretty.replace("rest", "REST API")
            if pretty not in found:
                found.append(pretty)

    # Metinde gecis sirasina gore biraz daha dengeli yapmak icin:
    # (Heuristik listemiz sabit oldugu icin burada sadece max_tags sinirlayiyoruz.)
    return found[:max_tags]


def extract_skill_tags(text: str, max_tags: int = 10) -> list[str]:
    """
    Serbest metinden yetkinlik/teknoloji tag'lerini cikarir.
    - OPENAI_API_KEY varsa OpenAI ile cikarim yapar.
    - Yoksa keyword tabanli fallback kullanir.
    """
    text = (text or "").strip()
    if not text:
        return []

    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        return _heuristic_skill_tags(text, max_tags=max_tags)

    from openai import OpenAI

    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    client = OpenAI(api_key=api_key)

    system = (
        "Sen bir yazilim is ilanindan teknoloji yetkinlikleri cikarirsin. "
        "Sadece gercekci (kullanim/teknoloji) tag'ler ver. "
        "Cikardigin tagler tekil ve kisaltma/teknoloji adlari seklinde olsun."
    )
    user = (
        "Asagidaki metinden en fazla {max_tags} adet teknoloji / yetkinlik etiketi cikar. "
        "Sadece bir JSON dondur: {\"tags\": [\"tag1\", \"tag2\", ...]}\n\n"
        "METIN:\n{text}"
    ).format(max_tags=max_tags, text=text)

    resp = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        response_format={"type": "json_object"},
    )

    content = resp.choices[0].message.content or "{}"
    parsed = json.loads(content)
    tags = parsed.get("tags", [])
    # Temizleme: bos ve tekrari kaldir
    cleaned: list[str] = []
    for t in tags:
        t = str(t).strip()
        if not t:
            continue
        # Basliklari guzellesitir (minimal)
        t = re.sub(r"\\s+", " ", t)
        if t not in cleaned:
            cleaned.append(t)

    return cleaned[:max_tags]


def _deterministic_embedding(text: str, dim: int) -> list[float]:
    """
    OpenAI embedding yoksa bile Milvus demo calissin diye deterministik vektor uretiyoruz.
    Not: Bu vektorler semantik anlam tasimaz ama boyut uyumu saglar.
    """
    seed = hashlib.sha256((text or "").encode("utf-8")).digest()
    vec: list[float] = []
    for i in range(dim):
        h = hashlib.sha256(seed + i.to_bytes(4, "big")).digest()
        # 0..1 araligi
        val = int.from_bytes(h[:4], "big") / 2**32
        vec.append(float(val))
    return vec


_TR_ASCII = str.maketrans(
    {
        "ç": "c",
        "Ç": "C",
        "ğ": "g",
        "Ğ": "G",
        "ı": "i",
        "İ": "I",
        "ö": "o",
        "Ö": "O",
        "ş": "s",
        "Ş": "S",
        "ü": "u",
        "Ü": "U",
    }
)


def ascii_clean_matchmaking_text(s: str) -> str:
    """Turkish letters to ASCII, collapse whitespace, lowercase (stable embedding strings)."""
    if not s:
        return ""
    t = str(s).translate(_TR_ASCII)
    t = re.sub(r"\s+", " ", t).strip().lower()
    return t


def build_matchmaking_user_embedding_text(title: str, bio: str, skill_names: list[str]) -> str:
    """Fixed lowercase English template for user vectors (Milvus)."""
    role = ascii_clean_matchmaking_text(title or "")
    skills = ", ".join(
        ascii_clean_matchmaking_text(x) for x in (skill_names or []) if x and str(x).strip()
    )
    exp = ascii_clean_matchmaking_text(bio or "")
    if not role and not skills and not exp:
        return ""
    return (
        f"role: {role or 'unspecified'}. "
        f"skills: {skills or 'none'}. "
        f"experience: {exp or 'none'}"
    )


def build_matchmaking_project_embedding_text(title: str, description: str, skill_names: list[str]) -> str:
    """Fixed lowercase English template for project vectors (Milvus)."""
    proj = ascii_clean_matchmaking_text(title or "")
    reqs = ", ".join(
        ascii_clean_matchmaking_text(x) for x in (skill_names or []) if x and str(x).strip()
    )
    desc = ascii_clean_matchmaking_text(description or "")
    if not proj and not reqs and not desc:
        return ""
    return (
        f"project: {proj or 'untitled'}. "
        f"requirements: {reqs or 'none'}. "
        f"description: {desc or 'none'}"
    )


def developer_profile_skill_names(dev) -> list[str]:
    from ..models import DeveloperProfile

    if not isinstance(dev, DeveloperProfile):
        return []
    return [
        row.skill.name
        for row in dev.user_skills.select_related("skill").all()
        if row.skill_id and row.skill and row.skill.name
    ]


def project_required_skill_names(project) -> list[str]:
    from ..models import ProjectPost

    if not isinstance(project, ProjectPost):
        return []
    return [
        row.skill.name
        for row in project.required_skills.select_related("skill").all()
        if row.skill_id and row.skill and row.skill.name
    ]


def build_user_profile_index_text(title: str, bio: str, skill_names: list[str]) -> str:
    """
    Milvus kullanici koleksiyonu ve yeniden indeksleme icin sabit sablon.
    Ornek: "Senior Backend Engineer focusing on Python, Django, PostgreSQL." + bio
    """
    skills = [s.strip() for s in (skill_names or []) if s and str(s).strip()]
    title_s = (title or "").strip()
    bio_s = (bio or "").strip()
    if skills:
        skill_part = ", ".join(skills)
        if title_s:
            head = f"{title_s} focusing on {skill_part}."
        else:
            head = f"Developer focusing on {skill_part}."
    else:
        head = title_s
    parts: list[str] = []
    if head:
        parts.append(head)
    if bio_s:
        parts.append(bio_s)
    return "\n".join(parts).strip()


def compute_embedding(text: str) -> list[float]:
    """
    Metinden embedding uretir.
    - OPENAI_API_KEY varsa OpenAI embeddings kullanilir.
    - Yoksa deterministik fallback vektor uretir.
    """
    cfg = _get_embedding_config()
    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    dim = cfg["dim"]
    model = cfg["model"]

    if not api_key:
        logger.info(
            "compute_embedding: OPENAI_API_KEY yok; deterministik vektor (semantik degil, dim=%s).",
            dim,
        )
        return _deterministic_embedding(text, dim=dim)

    from openai import OpenAI

    client = OpenAI(api_key=api_key)
    # OpenAI embedding fonksiyonunda input tek metin olarak verilir.
    resp = client.embeddings.create(model=model, input=text)
    emb = resp.data[0].embedding  # list[float]
    # Dim kontrol
    if len(emb) != dim:
        # Boyut sapmasi durumunda, fallback ile uyum sagla.
        logger.warning(
            "compute_embedding: OpenAI boyut uyumsuz (beklenen=%s gelen=%s); deterministik vektor.",
            dim,
            len(emb),
        )
        return _deterministic_embedding(text, dim=dim)
    floats = [float(x) for x in emb]
    sq = sum(x * x for x in floats)
    if sq < 1e-20:
        logger.warning(
            "compute_embedding: embedding normu cok dusuk (||v||^2=%s); bos veya anlamsiz metin olabilir.",
            sq,
        )
    return floats


def milvus_upsert_project_embedding(
    *,
    project_id: int,
    embedding: list[float],
) -> dict[str, Any]:
    """
    Milvus'e proje embedding'i yazar.
    Bu fonksiyon, collection yoksa otomatik olusturur.
    """
    collection_name = os.getenv("MILVUS_PROJECT_COLLECTION", "project_post_embeddings")
    dim = int(os.getenv("OPENAI_EMBEDDING_DIM", "1536"))

    from .milvus_client import MILVUS_CONN_ALIAS, milvus_connect_default, milvus_disconnect_default

    try:
        from pymilvus import (
            Collection,
            CollectionSchema,
            DataType,
            FieldSchema,
            utility,
        )

        milvus_connect_default(timeout=5)

        if not utility.has_collection(collection_name, using=MILVUS_CONN_ALIAS):
            fields = [
                FieldSchema(name="project_id", dtype=DataType.INT64, is_primary=True, auto_id=False),
                FieldSchema(name="embedding", dtype=DataType.FLOAT_VECTOR, dim=dim),
            ]
            schema = CollectionSchema(fields=fields, description="Project embeddings (NLP week 5)")
            Collection(name=collection_name, schema=schema, using=MILVUS_CONN_ALIAS)

        collection = Collection(name=collection_name, using=MILVUS_CONN_ALIAS)
        collection.load()

        if len(embedding) != dim:
            # Milvus'a yazmadan once dim uydur.
            embedding = _deterministic_embedding(str(project_id), dim=dim)

        # upsert: pk ayniysa gunceller
        data = [{"project_id": int(project_id), "embedding": [float(x) for x in embedding]}]
        collection.upsert(data)
        collection.flush()

        return {"ok": True, "collection": collection_name, "project_id": project_id}
    except Exception as exc:  # pragma: no cover
        return {"ok": False, "error": str(exc), "collection": collection_name}
    finally:
        milvus_disconnect_default()


def milvus_upsert_user_embedding(
    *,
    user_id: int,
    embedding: list[float],
) -> dict[str, Any]:
    """
    Milvus'e kullanici profil embedding'i yazar.
    Collection yoksa otomatik olusturur.
    """
    collection_name = os.getenv("MILVUS_USER_COLLECTION", "user_profile_embeddings")
    dim = int(os.getenv("OPENAI_EMBEDDING_DIM", "1536"))

    from .milvus_client import MILVUS_CONN_ALIAS, milvus_connect_default, milvus_disconnect_default

    try:
        from pymilvus import (
            Collection,
            CollectionSchema,
            DataType,
            FieldSchema,
            utility,
        )

        milvus_connect_default(timeout=5)

        if not utility.has_collection(collection_name, using=MILVUS_CONN_ALIAS):
            fields = [
                FieldSchema(name="user_id", dtype=DataType.INT64, is_primary=True, auto_id=False),
                FieldSchema(name="embedding", dtype=DataType.FLOAT_VECTOR, dim=dim),
            ]
            schema = CollectionSchema(fields=fields, description="User profile embeddings")
            Collection(name=collection_name, schema=schema, using=MILVUS_CONN_ALIAS)

        collection = Collection(name=collection_name, using=MILVUS_CONN_ALIAS)
        collection.load()

        if len(embedding) != dim:
            embedding = _deterministic_embedding(str(user_id), dim=dim)

        data = [{"user_id": int(user_id), "embedding": [float(x) for x in embedding]}]
        collection.upsert(data)
        collection.flush()
        return {"ok": True, "collection": collection_name, "user_id": user_id}
    except Exception as exc:  # pragma: no cover
        return {"ok": False, "error": str(exc), "collection": collection_name}
    finally:
        milvus_disconnect_default()


def upsert_project_post_milvus(project) -> dict[str, Any]:
    """Writes project vector to Milvus using the fixed English matchmaking template."""
    from django.utils import timezone

    from ..models import EmbeddingMeta, ProjectPost

    fresh = (
        ProjectPost.objects.prefetch_related("required_skills__skill")
        .select_related("owner")
        .get(pk=project.pk)
    )
    skills = project_required_skill_names(fresh)
    text = build_matchmaking_project_embedding_text(
        fresh.title or "",
        fresh.description or "",
        skills,
    )
    if not text.strip():
        return {"ok": False, "skipped": True, "reason": "bos_icerik"}
    embedding = compute_embedding(text)
    milvus_result = milvus_upsert_project_embedding(project_id=fresh.id, embedding=embedding)
    if milvus_result.get("ok"):
        EmbeddingMeta.objects.update_or_create(
            entity_type=EmbeddingMeta.EntityType.PROJECT_POST,
            entity_id=fresh.id,
            defaults={
                "milvus_vector_id": fresh.id,
                "last_embedded_at": timezone.now(),
            },
        )
    return milvus_result


def upsert_developer_profile_milvus(dev) -> dict[str, Any]:
    """Writes developer profile vector to Milvus using the fixed English matchmaking template."""
    from django.utils import timezone

    from ..models import DeveloperProfile, EmbeddingMeta

    fresh = (
        DeveloperProfile.objects.select_related("user")
        .prefetch_related("user_skills__skill")
        .get(pk=dev.pk)
    )
    skills = developer_profile_skill_names(fresh)
    text = build_matchmaking_user_embedding_text(
        fresh.title or "",
        fresh.bio or "",
        skills,
    )
    if not text.strip():
        return {"ok": False, "skipped": True, "reason": "bos_profil"}
    embedding = compute_embedding(text)
    milvus_result = milvus_upsert_user_embedding(user_id=fresh.user_id, embedding=embedding)
    if milvus_result.get("ok"):
        EmbeddingMeta.objects.update_or_create(
            entity_type=EmbeddingMeta.EntityType.DEVELOPER_PROFILE,
            entity_id=fresh.id,
            defaults={
                "milvus_vector_id": fresh.user_id,
                "last_embedded_at": timezone.now(),
            },
        )
    return milvus_result


def reindex_project_post_milvus(project) -> dict[str, Any]:
    """Ilan icerigi degistiginde Milvus vektorunu gunceller (sablon + saglik kontrolu)."""
    from .milvus_client import milvus_health

    milvus_health_status = milvus_health()
    if not milvus_health_status.get("ok"):
        return {
            "ok": False,
            "skipped": True,
            "reason": "Milvus erisilemiyor",
            "health": milvus_health_status,
        }
    return upsert_project_post_milvus(project)


def reindex_all_milvus_entities(
    *,
    projects_limit: int | None = None,
    users_limit: int | None = None,
) -> dict[str, Any]:
    from ..models import DeveloperProfile, ProjectPost
    from .milvus_client import milvus_health

    health = milvus_health()
    if not health.get("ok"):
        return {"ok": False, "error": "Milvus erisilemiyor", "health": health}

    pq = ProjectPost.objects.prefetch_related("required_skills__skill").select_related("owner").order_by("-id")
    uq = DeveloperProfile.objects.select_related("user").prefetch_related("user_skills__skill").order_by("-id")
    if projects_limit is not None:
        pq = pq[: max(0, projects_limit)]
    if users_limit is not None:
        uq = uq[: max(0, users_limit)]

    projects_ok = 0
    users_ok = 0
    for p in pq:
        r = upsert_project_post_milvus(p)
        if r.get("ok"):
            projects_ok += 1
    for d in uq:
        r = upsert_developer_profile_milvus(d)
        if r.get("ok"):
            users_ok += 1

    msg = f"Milvus reindex: {projects_ok} proje, {users_ok} kullanici yazildi."
    logger.info(msg)
    return {
        "ok": True,
        "message": msg,
        "milvus_health": health,
        "projects_indexed": projects_ok,
        "users_indexed": users_ok,
    }


def milvus_hard_reset_and_reindex_entities(
    *,
    projects_limit: int | None = None,
    users_limit: int | None = None,
) -> dict[str, Any]:
    from .milvus_client import milvus_drop_default_collections, milvus_health

    drop = milvus_drop_default_collections()
    if not drop.get("ok"):
        return {"ok": False, "phase": "drop", **drop}

    health = milvus_health()
    if not health.get("ok"):
        return {"ok": False, "phase": "health", "error": "Milvus erisilemiyor", "health": health, "drop": drop}

    inner = reindex_all_milvus_entities(projects_limit=projects_limit, users_limit=users_limit)
    inner["drop"] = drop
    if inner.get("ok"):
        inner["message"] = (
            f"MILVUS HARD RESET: koleksiyonlar silindi; "
            f"{inner.get('projects_indexed')} proje, {inner.get('users_indexed')} kullanici yeniden indekslendi."
        )
        logger.info("%s", inner["message"])
    else:
        inner.setdefault(
            "message",
            inner.get("error") or "Reindex after drop failed",
        )
        logger.warning("milvus_hard_reset_and_reindex_entities: %s", inner["message"])
    return inner

