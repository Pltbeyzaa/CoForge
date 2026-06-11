## CoForge — Haftalık İş Paketi Planı (11 Hafta)

Kaynak: `İş_Paketleri.docx` (metne dönüştürülmüş hali: `_docs/Is_Paketleri.txt`)

### 1. Hafta — İş Paketlerinin hazırlanması ve planlama
- **Kapsam**: Projenin genel hatları, hedef kitle, gereksinimler.
- **Görevler**:
  - Gereksinim analizi dokümanı
  - Web + mobil (Flutter) ekran taslakları (wireframe)
  - Kullanıcı akış (user flow) diyagramları
- **Beklenen çıktı**: Onaylanmış gereksinim belgesi + arayüz taslakları
- **Demo**: “İlan oluşturma → eşleşme bildirimi → takım ekranı” akışının kağıt üstünde gösterimi (tıklanabilir olmasa da adım adım)

### 2. Hafta — Mimari tasarım ve veritabanı kurulumu
- **Kapsam**: Veri modelinin tasarımı.
- **Görevler**:
  - MySQL ER diyagramı (Kullanıcı, İlan, Takım, Yetkinlik)
  - İlişkiler ve FK’ler
- **Beklenen çıktı**: Kodlamaya hazır veritabanı şeması
- **Demo**: ER diyagram + örnek API kaynak listesi (User/Profile/Post/Team/Skill)

### 3. Hafta — Core backend ve REST API (başlangıç)
- **Kapsam**: Backend iskeleti.
- **Görevler**:
  - Django proje başlatma
  - MySQL bağlantısı
  - JWT tabanlı auth (register/login)
- **Beklenen çıktı**: Kullanıcı doğrulaması yapan temel API
- **Demo**: Postman ile register/login + token ile korunmuş endpoint çağrısı

### 4. Hafta — Backend tamamlanması + NLP altyapısına giriş
- **Kapsam**: CRUD tamam, Milvus entegrasyonu başlar.
- **Görevler**:
  - İlan oluşturma + profil güncelleme DRF endpoint’leri
  - Milvus bağlantısı ve temel koleksiyon/indeks hazırlığı
- **Beklenen çıktı**: Stabil backend API + Milvus bağlantısı
- **Demo**: İlan yarat → Milvus’a embedding yaz → health/diagnostics endpoint

### 5. Hafta — NLP ve akıllı eşleştirme (geliştirme)
- **Kapsam**: Metinden tag çıkarımı + vektörleştirme.
- **Görevler**:
  - OpenAI API (veya spaCy) ile yetkinlik tag çıkarımı
  - Tag/embedding üretimi ve saklama stratejisi
- **Beklenen çıktı**: Serbest metinden doğru yetkinlikleri çıkaran NLP servisi
- **Demo**: “React + Django + Redis…” metninden tag listesi üretimi

### 6. Hafta — Eşleştirme bitişi + web frontend başlangıcı
- **Kapsam**: Matchmaking tamam; web panel iskeleti.
- **Görevler**:
  - Milvus similarity search ile matchmaking
  - Web panel (HTML/CSS/JS) iskeleti
- **Beklenen çıktı**: Aday filtreleyen algoritma + ilk web sayfaları
- **Demo**: İlan için “top-k geliştirici önerileri” ekranı

### 7. Hafta — Web ve mobil frontend (geliştirme)
- **Kapsam**: UI’lar + API entegrasyonu.
- **Görevler**:
  - Flutter ekranları
  - Web + mobil API entegrasyonu
- **Beklenen çıktı**: İlanları görüntüleyen ve veri alışverişi yapan uygulamalar
- **Demo**: Mobilde ilan listesi + bildirim mock’u

### 8. Hafta — Frontend tamam + otonom AI Scrum Master başlangıcı
- **Kapsam**: Takım ekranları + AI backlog/WBS taslağı.
- **Görevler**:
  - Takım kurulum ekranları
  - İlan metninden backlog/WBS üreten prompt/algoritma
- **Beklenen çıktı**: Projeyi alt görevlere bölen AI taslağı
- **Demo**: “WBS + backlog” JSON çıktısı

### 9. Hafta — AI Scrum Master bitişi + değerlendirme modülü başlangıcı
- **Kapsam**: Sprint/Gantt + 360 form altyapısı.
- **Görevler**:
  - Görevleri sprint/Gantt formatına dökme
  - 360 değerlendirme formu DB + arayüz altyapısı
- **Beklenen çıktı**: Proje yönetim ekranı + anket formları
- **Demo**: Gantt verisi üretimi + form doldurma

### 10. Hafta — Puanlama algoritması + genel testlere giriş
- **Kapsam**: Skor hesapları + E2E test.
- **Görevler**:
  - 360 metin analizinden “Güvenilirlik Skoru”
  - Matchmaking/görev atama/API E2E test
- **Beklenen çıktı**: Skorlama sistemi + bug raporları
- **Demo**: Örnek geri bildirimlerden skor üretimi

### 11. Hafta — Testleri bitirme ve canlıya alma (deployment)
- **Kapsam**: Hata düzelt + container + deploy.
- **Görevler**:
  - Bug fix
  - Docker + Nginx + Gunicorn ile yayın
- **Beklenen çıktı**: Canlı ortamda çalışan CoForge
- **Demo**: Production URL + temel izleme/log’lar

### Riskler ve B planı (özet)
- **Milvus/NLP gecikmesi**: MVP’de keyword tabanlı matching (MySQL) → semantic Faz-2
- **AI Scrum Master hatalı plan**: “insan onaylı taslak (draft)” akışı
- **Mobil yetişmezse**: Öncelik web; mobil read-only bildirim uygulaması
- **NLP maliyet/hız**: Asenkron kuyruk / gecelik batch işleme

