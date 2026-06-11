## 6. Hafta — Matchmaking Motoru + Web Önizleme

Tüm endpoint’ler `Authorization: Bearer <access_token>` gerektirir (JWT).

### Eşleşme önerileri (MatchSuggestion)

#### Aday önerileri üret (Milvus + keyword fallback)

| Metod | URL | Açıklama |
|------|-----|----------|
| `POST` | `/api/me/match-suggestions/` | Kullanıcının yetkinliklerine göre ilan önerileri üretir ve `MatchSuggestion` kaydı oluşturur. |

Request body örnek:
```json
{
  "top_k": 10,
  "max_tags": 20
}
```

Dönen yanıt örnek:
```json
{
  "ok": true,
  "source": "milvus",
  "developer_tags": ["Django REST Framework", "Milvus"],
  "matches": [
    {
      "project_id": 1,
      "project_title": "Backend Projesi",
      "score": "0.87",
      "suggestion_status": "suggested"
    }
  ],
  "milvus": {
    "health": { "ok": true, "version": "..." },
    "collection": "project_post_embeddings"
  }
}
```

Notlar:
- Milvus sağlıksızsa cevap `source: "keyword"` döner (fallback overlap skoruyla adaylar seçilir).
- Öneri oluşturulan ilanlar `ProjectPost.status` olarak `matching` state'ine alınır (sadece `OPEN` iken).

#### Kaydedilmiş önerileri listele

| Metod | URL | Açıklama |
|------|-----|----------|
| `GET` | `/api/me/match-suggestions/?top_k=10&status=suggested` | Kullanıcının daha önce ürettiği `MatchSuggestion` kayıtlarını listeler. |

