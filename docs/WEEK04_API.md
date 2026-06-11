# 4. Hafta — DRF CRUD + Milvus entegrasyonu (başlangıç)

Tüm endpoint’ler `Authorization: Bearer <access_token>` gerektirir (JWT).

## Profil (geliştirici)

| Metod | URL | Açıklama |
|------|-----|----------|
| `GET` | `/api/me/profile/` | Oturumdaki kullanıcı için `DeveloperProfile` (yoksa oluşturulur) |
| `PATCH` | `/api/me/profile/` | Profil güncelle |

## Yetkinlikler (Skill)

| Metod | URL | Açıklama |
|------|-----|----------|
| `GET` | `/api/skills/` | Skill listesi |
| `POST` | `/api/skills/` | Yeni skill (`name`, `category`, `description`) |
| `GET` | `/api/skills/{id}/` | Tekil skill |
| `PUT/PATCH` | `/api/skills/{id}/` | Güncelle |
| `DELETE` | `/api/skills/{id}/` | Sil |

## Kullanıcı yetkinlikleri (UserSkill)

| Metod | URL | Açıklama |
|------|-----|----------|
| `GET` | `/api/me/skills/` | Kendi profilindeki yetkinlikler |
| `POST` | `/api/me/skills/` | Ekle: `skill_id`, `level`, `years_experience` |
| `DELETE` | `/api/me/skills/{id}/` | Kendi kaydını sil |

## İlan (ProjectPost)

| Metod | URL | Açıklama |
|------|-----|----------|
| `GET` | `/api/project-posts/` | Liste |
| `POST` | `/api/project-posts/` | Oluştur (owner = oturumdaki kullanıcı). İsteğe bağlı: `required_skills: [{ "skill_id": 1, "priority": 1 }]` |
| `GET` | `/api/project-posts/{id}/` | Detay |
| `PUT/PATCH` | `/api/project-posts/{id}/` | Sadece **ilan sahibi** |
| `DELETE` | `/api/project-posts/{id}/` | Sadece **ilan sahibi** |

Yanıtta `required_skills_detail` alanı, ilişkili skill’leri okumak içindir.

## Milvus sağlık kontrolü

| Metod | URL | Açıklama |
|------|-----|----------|
| `GET` | `/api/health/milvus/` | Milvus sunucusuna bağlanıp sürüm bilgisi döner (`ok: true/false`) |

Milvus’u test etmek için: `docker compose -f infra/docker-compose.yml up -d` (MySQL + Milvus stack).
