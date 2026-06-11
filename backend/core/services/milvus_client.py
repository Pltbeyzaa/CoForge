from __future__ import annotations

import json
import logging
import os
from typing import Any

logger = logging.getLogger(__name__)

# PyMilvus: utility.* ve parametresiz Collection() "default" alias'ini kullanir.
# Ozel alias ile baglanip default'suz API cagirmak ConnectionNotExistException verir.
MILVUS_CONN_ALIAS = "default"


def _milvus_host_port() -> tuple[str, str]:
    return os.getenv("MILVUS_HOST", "127.0.0.1"), os.getenv("MILVUS_PORT", "19530")


def milvus_connect_default(*, timeout: float | int = 60) -> None:
    """Drop / health / upsert / search oncesi Milvus baglantisini default alias ile kurar."""
    from pymilvus import connections

    host, port = _milvus_host_port()
    if connections.has_connection(MILVUS_CONN_ALIAS):
        try:
            connections.disconnect(MILVUS_CONN_ALIAS)
        except Exception:
            pass
    connections.connect(alias=MILVUS_CONN_ALIAS, host=host, port=port, timeout=timeout)


def milvus_disconnect_default() -> None:
    try:
        from pymilvus import connections

        if connections.has_connection(MILVUS_CONN_ALIAS):
            connections.disconnect(MILVUS_CONN_ALIAS)
    except Exception:
        pass


def _normalize_search_score(*, raw: float, metric_type: str) -> float:
    """
    Milvus arama ciktisini 0..1 araliginda 'benzerlik' skoruna cevirir.
    - IP / COSINE: genelde yuksek = daha yakin (Milvus surumune gore 0..1 veya benzer).
    - L2: distance dusuk = daha yakin; 1/(1+d) ile 0..1 araligina map edilir.
    """
    m = (metric_type or "IP").upper()
    if m in ("L2", "EUCLIDEAN"):
        d = max(0.0, float(raw))
        return float(1.0 / (1.0 + d))
    x = float(raw)
    if x > 1.0:
        return min(1.0, max(0.0, x / 100.0))
    return min(1.0, max(0.0, x))


def _milvus_vector_search(collection: Any, *, embedding: list[float], metric_type: str, nprobe: int, top_k: int, expr: str | None) -> Any:
    """FLAT / IVF fark etmeksizin arama; nprobe hatasinda params={} ile bir kez daha dener."""

    def _call(param: dict[str, Any]) -> Any:
        kwargs: dict[str, Any] = {
            "data": [embedding],
            "anns_field": "embedding",
            "param": param,
            "limit": top_k,
            "output_fields": [],
        }
        if expr:
            kwargs["expr"] = expr
        return collection.search(**kwargs)

    primary = {"metric_type": metric_type, "params": {"nprobe": nprobe}}
    try:
        return _call(primary)
    except Exception as exc:  # pragma: no cover
        logger.warning("Milvus search retry without nprobe (expr=%s): %s", expr, exc)
        return _call({"metric_type": metric_type, "params": {}})


def _inspect_vector_collection(*, alias: str, collection_name: str) -> dict[str, Any]:
    """Tek koleksiyon: var mi, satir sayisi, embedding alan boyutu."""
    from pymilvus import Collection, DataType, utility

    row: dict[str, Any] = {
        "name": collection_name,
        "exists": False,
        "num_entities": 0,
        "vector_dim_in_schema": None,
    }
    if not utility.has_collection(collection_name, using=alias):
        return row
    col = Collection(name=collection_name, using=alias)
    col.load()
    row["exists"] = True
    try:
        row["num_entities"] = int(col.num_entities)
    except Exception:
        row["num_entities"] = -1
    for field in col.schema.fields:
        if field.dtype == DataType.FLOAT_VECTOR:
            params = getattr(field, "params", {}) or {}
            row["vector_dim_in_schema"] = params.get("dim")
            break
    return row


def milvus_collections_snapshot() -> dict[str, Any]:
    """
    Project + User embedding koleksiyonlarinin varligini, satir sayisini ve semadaki vektor boyutunu dondurur.
    OPENAI_EMBEDDING_DIM ile uyumu kontrol eder.
    """
    host = os.getenv("MILVUS_HOST", "127.0.0.1")
    port = os.getenv("MILVUS_PORT", "19530")
    project_name = os.getenv("MILVUS_PROJECT_COLLECTION", "project_post_embeddings")
    user_name = os.getenv("MILVUS_USER_COLLECTION", "user_profile_embeddings")
    expected = int(os.getenv("OPENAI_EMBEDDING_DIM", "1536"))
    out: dict[str, Any] = {
        "ok": False,
        "host": host,
        "port": port,
        "expected_embedding_dim": expected,
        "project_collection": {},
        "user_collection": {},
        "error": None,
    }
    alias = MILVUS_CONN_ALIAS
    try:
        milvus_connect_default(timeout=5)
        out["project_collection"] = _inspect_vector_collection(alias=alias, collection_name=project_name)
        out["user_collection"] = _inspect_vector_collection(alias=alias, collection_name=user_name)
        pd = out["project_collection"].get("vector_dim_in_schema")
        ud = out["user_collection"].get("vector_dim_in_schema")
        out["dim_matches_env"] = {
            "project": pd is None or int(pd) == expected,
            "user": ud is None or int(ud) == expected,
        }
        if out["project_collection"].get("exists") and pd is not None and int(pd) != expected:
            logger.error(
                "Milvus project koleksiyonu vektor boyutu env ile uyusmuyor: schema_dim=%s OPENAI_EMBEDDING_DIM=%s",
                pd,
                expected,
            )
        if out["user_collection"].get("exists") and ud is not None and int(ud) != expected:
            logger.error(
                "Milvus user koleksiyonu vektor boyutu env ile uyusmuyor: schema_dim=%s OPENAI_EMBEDDING_DIM=%s",
                ud,
                expected,
            )
        out["ok"] = True
    except Exception as exc:  # pragma: no cover
        out["error"] = str(exc)
        logger.warning("milvus_collections_snapshot failed: %s", exc)
    finally:
        milvus_disconnect_default()
    return out


def milvus_log_collections_snapshot(*, context: str = "") -> dict[str, Any]:
    """Terminal + logger: koleksiyon durumu (runserver konsolunda gorunur)."""
    snap = milvus_collections_snapshot()
    snap["context"] = context or "general"
    line = "[MILVUS_SNAPSHOT] " + json.dumps(snap, ensure_ascii=False, default=str)
    print(line, flush=True)
    logger.info("%s", line)
    return snap


def milvus_drop_default_collections() -> dict[str, Any]:
    """
    Env ile adlari verilen project + user embedding koleksiyonlarini kalici olarak siler.
    Hard reset sonrasi upsert ilk yazimda koleksiyonu OPENAI_EMBEDDING_DIM ile yeniden yaratir.
    """
    host = os.getenv("MILVUS_HOST", "127.0.0.1")
    port = os.getenv("MILVUS_PORT", "19530")
    project_name = os.getenv("MILVUS_PROJECT_COLLECTION", "project_post_embeddings")
    user_name = os.getenv("MILVUS_USER_COLLECTION", "user_profile_embeddings")

    alias = MILVUS_CONN_ALIAS
    dropped: list[str] = []
    err: str | None = None
    try:
        from pymilvus import utility

        milvus_connect_default(timeout=60)
        for name in (project_name, user_name):
            if utility.has_collection(name, using=alias):
                utility.drop_collection(name, using=alias)
                dropped.append(name)
        return {"ok": True, "host": host, "port": port, "dropped": dropped}
    except Exception as exc:  # pragma: no cover
        err = str(exc)
        logger.warning("milvus_drop_default_collections failed: %s", exc)
        return {"ok": False, "host": host, "port": port, "dropped": dropped, "error": err}
    finally:
        milvus_disconnect_default()


def milvus_health() -> dict[str, Any]:
    """
    Lightweight connectivity check for Milvus (Week 4 integration).
    Does not create collections; only verifies server reachability.
    """
    host = os.getenv("MILVUS_HOST", "127.0.0.1")
    port = os.getenv("MILVUS_PORT", "19530")

    alias = MILVUS_CONN_ALIAS
    try:
        from pymilvus import utility

        milvus_connect_default(timeout=5)
        version = utility.get_server_version(using=alias)
        return {"ok": True, "host": host, "port": port, "version": version}
    except Exception as exc:  # pragma: no cover
        return {"ok": False, "host": host, "port": port, "error": str(exc)}
    finally:
        milvus_disconnect_default()


def milvus_search_project_embeddings(
    *,
    embedding: list[float],
    top_k: int = 10,
    exclude_project_ids: list[int] | None = None,
) -> dict[str, Any]:
    """
    Milvus'ta `project_post_embeddings` collection'ından benzer projeleri arar.

    Not: Bu repo içinde vektör alan adı `embedding`, primary key alan adı `project_id` olarak oluşturuluyor.
    exclude_project_ids: Bu id'ler aramadan çıkarılır (ör. kullanıcının kendi ilanları), expr ile Milvus tarafında.
    """
    collection_name = os.getenv("MILVUS_PROJECT_COLLECTION", "project_post_embeddings")
    dim = int(os.getenv("OPENAI_EMBEDDING_DIM", "1536"))

    metric_type = os.getenv("MILVUS_METRIC_TYPE", "IP").upper()
    nprobe = int(os.getenv("MILVUS_NPROBE", "10"))

    alias = MILVUS_CONN_ALIAS

    try:
        from pymilvus import Collection, utility

        milvus_connect_default(timeout=5)

        if not utility.has_collection(collection_name, using=alias):
            return {"ok": False, "error": "Milvus collection not found", "collection": collection_name}

        if len(embedding) != dim:
            return {
                "ok": False,
                "error": f"Embedding dim mismatch (expected={dim}, got={len(embedding)})",
                "collection": collection_name,
            }

        collection = Collection(name=collection_name, using=alias)
        collection.load()

        expr: str | None = None
        if exclude_project_ids:
            ids = sorted({int(x) for x in exclude_project_ids})
            if ids:
                expr = "project_id not in [" + ", ".join(str(i) for i in ids) + "]"

        search_results = _milvus_vector_search(
            collection,
            embedding=embedding,
            metric_type=metric_type,
            nprobe=nprobe,
            top_k=top_k,
            expr=expr,
        )

        matches: list[dict[str, Any]] = []
        for hit in search_results[0]:
            proj_id = getattr(hit, "id", None)
            if proj_id is None:
                continue
            score = getattr(hit, "score", None)
            distance = getattr(hit, "distance", None)
            raw = float(score if score is not None else (distance if distance is not None else 0.0))
            norm = _normalize_search_score(raw=raw, metric_type=metric_type)
            matches.append(
                {
                    "project_id": int(proj_id),
                    "score": norm,
                    "raw_milvus": raw,
                }
            )

        logger.info(
            "Milvus project search: collection=%s metric=%s top_k=%s expr=%s hits=%s sample=%s",
            collection_name,
            metric_type,
            top_k,
            expr,
            len(matches),
            [{"id": m.get("project_id"), "raw": m.get("raw_milvus"), "norm": m.get("score")} for m in matches[:8]],
        )

        return {"ok": True, "collection": collection_name, "matches": matches}
    except Exception as exc:  # pragma: no cover
        logger.warning(
            "Milvus project search failed collection=%s metric=%s: %s",
            collection_name,
            metric_type,
            exc,
        )
        return {"ok": False, "error": str(exc), "collection": collection_name}
    finally:
        milvus_disconnect_default()


def _milvus_search_embeddings(
    *,
    embedding: list[float],
    collection_name: str,
    id_key: str,
    top_k: int = 10,
    exclude_id: int | None = None,
) -> dict[str, Any]:
    dim = int(os.getenv("OPENAI_EMBEDDING_DIM", "1536"))
    metric_type = os.getenv("MILVUS_METRIC_TYPE", "IP").upper()
    nprobe = int(os.getenv("MILVUS_NPROBE", "10"))
    alias = MILVUS_CONN_ALIAS

    try:
        from pymilvus import Collection, utility

        milvus_connect_default(timeout=5)
        if not utility.has_collection(collection_name, using=alias):
            return {"ok": False, "error": "Milvus collection not found", "collection": collection_name}
        if len(embedding) != dim:
            return {
                "ok": False,
                "error": f"Embedding dim mismatch (expected={dim}, got={len(embedding)})",
                "collection": collection_name,
            }

        collection = Collection(name=collection_name, using=alias)
        collection.load()
        expr = f"{id_key} != {int(exclude_id)}" if exclude_id is not None else None
        search_results = _milvus_vector_search(
            collection,
            embedding=embedding,
            metric_type=metric_type,
            nprobe=nprobe,
            top_k=top_k,
            expr=expr,
        )

        matches: list[dict[str, Any]] = []
        for hit in search_results[0]:
            item_id = getattr(hit, "id", None)
            if item_id is None:
                continue
            score = getattr(hit, "score", None)
            distance = getattr(hit, "distance", None)
            raw = float(score if score is not None else (distance if distance is not None else 0.0))
            norm = _normalize_search_score(raw=raw, metric_type=metric_type)
            row: dict[str, Any] = {id_key: int(item_id), "score": norm, "raw_milvus": raw}
            matches.append(row)

        logger.info(
            "Milvus user search: collection=%s metric=%s top_k=%s hits=%s sample=%s",
            collection_name,
            metric_type,
            top_k,
            len(matches),
            [{**{k: m.get(k) for k in (id_key,)}, "raw": m.get("raw_milvus"), "norm": m.get("score")} for m in matches[:8]],
        )

        return {"ok": True, "collection": collection_name, "matches": matches}
    except Exception as exc:  # pragma: no cover
        logger.warning(
            "Milvus user search failed collection=%s metric=%s: %s",
            collection_name,
            metric_type,
            exc,
        )
        return {"ok": False, "error": str(exc), "collection": collection_name}
    finally:
        milvus_disconnect_default()


def milvus_search_user_embeddings(
    *,
    embedding: list[float],
    top_k: int = 10,
    exclude_user_id: int | None = None,
) -> dict[str, Any]:
    collection_name = os.getenv("MILVUS_USER_COLLECTION", "user_profile_embeddings")
    return _milvus_search_embeddings(
        embedding=embedding,
        collection_name=collection_name,
        id_key="user_id",
        top_k=top_k,
        exclude_id=exclude_user_id,
    )


def milvus_delete_project_embedding(*, project_id: int) -> dict[str, Any]:
    """Milvus project_post_embeddings koleksiyonundan ilgili vektoru siler."""
    collection_name = os.getenv("MILVUS_PROJECT_COLLECTION", "project_post_embeddings")
    alias = MILVUS_CONN_ALIAS

    try:
        from pymilvus import Collection, utility

        milvus_connect_default(timeout=5)
        if not utility.has_collection(collection_name, using=alias):
            return {"ok": True, "skipped": True, "collection": collection_name, "reason": "collection not found"}

        collection = Collection(name=collection_name, using=alias)
        collection.load()
        collection.delete(expr=f"project_id == {int(project_id)}")
        return {"ok": True, "collection": collection_name, "project_id": int(project_id)}
    except Exception as exc:  # pragma: no cover
        return {"ok": False, "error": str(exc), "collection": collection_name}
    finally:
        milvus_disconnect_default()
