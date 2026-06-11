## CoForge — MySQL ER Diyagramı (MVP)

Bu doküman, 2. haftanın kapsamı olan **veritabanı mimarisi** ve MySQL şemasını özetler. Amaç, 3. haftada Django modellerine direkt çevrilebilecek net bir taslak oluşturmaktır.

> Not: Vektör veritabanı (Milvus) için embedding verileri MySQL’de sadece **meta** olarak tutulur; gerçek vektörler Milvus’ta saklanır.

---

### 1. Çekirdek kullanıcı ve profil tabloları

#### `users`
- **id** (PK, BIGINT, auto increment)
- **email** (VARCHAR(255), unique, not null)
- **password_hash** (VARCHAR(255), not null)
- **full_name** (VARCHAR(255), not null)
- **role** (ENUM: `owner`, `developer`, `admin`, default `developer`)
- **is_active** (BOOLEAN / TINYINT(1), default 1)
- **created_at** (DATETIME, default CURRENT_TIMESTAMP)
- **updated_at** (DATETIME, default CURRENT_TIMESTAMP on update)

**İlişkiler**:
- 1:N → `developer_profiles` (`users.id` → `developer_profiles.user_id`)
- 1:N → `project_posts` (`users.id` → `project_posts.owner_id`)
- 1:N → `team_members` (`users.id` → `team_members.user_id`)
- 1:N → `evaluations` (hem evaluator_id hem evaluatee_id)

#### `developer_profiles`
- **id** (PK, BIGINT)
- **user_id** (FK → `users.id`, unique, not null)
- **title** (VARCHAR(255), nullable)
- **bio** (TEXT, nullable)
- **experience_level** (ENUM: `junior`, `mid`, `senior`, `lead`)
- **years_experience** (INT, nullable)
- **location** (VARCHAR(255), nullable)
- **is_open_to_projects** (BOOLEAN, default 1)
- **created_at**, **updated_at**

**İlişkiler**:
- 1:N → `user_skills` (`developer_profiles.id` → `user_skills.profile_id`)
- 1:N → `embedding_meta` (entity_type=`developer_profile`)

---

### 2. Yetkinlik (Skill) ve etiketleme yapısı

#### `skills`
- **id** (PK, BIGINT)
- **name** (VARCHAR(100), unique, not null) — örn: `Python`, `React`
- **category** (VARCHAR(100), nullable) — örn: `backend`, `frontend`, `devops`
- **description** (TEXT, nullable)
- **created_at**, **updated_at**

#### `user_skills`
- **id** (PK, BIGINT)
- **profile_id** (FK → `developer_profiles.id`, not null)
- **skill_id** (FK → `skills.id`, not null)
- **level** (ENUM: `beginner`, `intermediate`, `advanced`, `expert`)
- **years_experience** (INT, nullable)

Unique constraint:
- (`profile_id`, `skill_id`)

#### `project_required_skills`
- **id** (PK, BIGINT)
- **project_id** (FK → `project_posts.id`, not null)
- **skill_id** (FK → `skills.id`, not null)
- **priority** (TINYINT, default 1) — 1: temel, 2: tercih edilen vs.

Unique constraint:
- (`project_id`, `skill_id`)

---

### 3. İlan (Project) ve takım yapısı

#### `project_posts`
- **id** (PK, BIGINT)
- **owner_id** (FK → `users.id`, not null) — ilan sahibi
- **title** (VARCHAR(255), not null)
- **description** (TEXT, not null) — proje metni (NLP bu metni okur)
- **status** (ENUM: `draft`, `open`, `matching`, `in_progress`, `completed`, `cancelled`; default `open`)
- **max_team_size** (INT, nullable)
- **created_at**, **updated_at**

**İlişkiler**:
- 1:N → `project_required_skills`
- 1:1 → `teams` (MVP’de her proje için tek aktif takım varsayımı)
- 1:N → `embedding_meta` (entity_type=`project_post`)

#### `teams`
- **id** (PK, BIGINT)
- **project_id** (FK → `project_posts.id`, unique, not null)
- **name** (VARCHAR(255), nullable) — default: proje başlığı
- **status** (ENUM: `forming`, `active`, `completed`, `cancelled`; default `forming`)
- **created_at**, **updated_at**

#### `team_members`
- **id** (PK, BIGINT)
- **team_id** (FK → `teams.id`, not null)
- **user_id** (FK → `users.id`, not null)
- **role_in_team** (ENUM: `owner`, `developer`, `scrum_master`; default `developer`)
- **joined_at** (DATETIME)

Unique constraint:
- (`team_id`, `user_id`)

---

### 4. Bildirim ve eşleştirme meta verisi

#### `notifications`
- **id** (PK, BIGINT)
- **user_id** (FK → `users.id`, not null)
- **type** (VARCHAR(100), not null)  
  Örn: `match_invite`, `project_update`, `evaluation_request`
- **payload** (JSON, nullable) — ilgili ilan/proje/ekip bilgileri
- **is_read** (BOOLEAN, default 0)
- **created_at** (DATETIME, default CURRENT_TIMESTAMP)

> Bu tablo, “akıllı eşleştirme sonucu geliştiriciye giden bildirimler” için de kullanılır.

#### `match_suggestions` (opsiyonel ama önerilen)
- **id** (PK, BIGINT)
- **project_id** (FK → `project_posts.id`, not null)
- **developer_profile_id** (FK → `developer_profiles.id`, not null)
- **score** (DECIMAL(5,2), not null) — eşleşme skoru (0–100)
- **status** (ENUM: `suggested`, `notified`, `accepted`, `rejected`; default `suggested`)
- **created_at**

Unique constraint:
- (`project_id`, `developer_profile_id`)

---

### 5. Değerlendirme ve skor sistemi

#### `evaluations`
- **id** (PK, BIGINT)
- **project_id** (FK → `project_posts.id`, not null)
- **evaluator_id** (FK → `users.id`, not null)
- **evaluatee_id** (FK → `users.id`, not null)
- **rating_overall** (TINYINT, nullable, 1–5)
- **rating_skill** (TINYINT, nullable, 1–5)
- **rating_communication** (TINYINT, nullable, 1–5)
- **comments** (TEXT, nullable) — 360 derece serbest metin geri bildirim
- **created_at** (DATETIME, default CURRENT_TIMESTAMP)

Unique constraint:
- (`project_id`, `evaluator_id`, `evaluatee_id`)

#### `profile_scores`
- **id** (PK, BIGINT)
- **user_id** (FK → `users.id`, not null)
- **project_id** (FK → `project_posts.id`, nullable) — belirli proje bazlı skor veya genel skor
- **success_score** (DECIMAL(5,2), not null) — 0–100
- **trust_score** (DECIMAL(5,2), not null) — 0–100
- **calculated_at** (DATETIME, default CURRENT_TIMESTAMP)

Unique indeks:
- (`user_id`, `project_id`)

---

### 6. Vektör veritabanı ile entegrasyon meta verisi

#### `embedding_meta`
- **id** (PK, BIGINT)
- **entity_type** (ENUM: `developer_profile`, `project_post`)
- **entity_id** (BIGINT, not null) — ilgili tablodaki satır id’si
- **milvus_vector_id** (BIGINT, nullable) — Milvus içindeki id (eğer kullanılırsa)
- **last_embedded_at** (DATETIME, nullable)

Unique constraint:
- (`entity_type`, `entity_id`)

---

### 7. Genel notlar
- Tüm tablolar için `created_at` / `updated_at` sütunlarını standart hale getirmek, Django modelleri ile bire bir eşleşmeyi kolaylaştırır.
- ENUM alanları Django tarafında `choices` olarak tanımlanacaktır.
- Milvus gecikmesi durumunda (dokümandaki Risk-1), `skills` / `user_skills` / `project_required_skills` üzerinden **keyword tabanlı eşleştirme** yapılabilir; ER yapısı bunu destekleyecek şekilde kurgulanmıştır.

