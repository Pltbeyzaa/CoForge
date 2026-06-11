## CoForge — Gereksinim Analizi (MVP)

### 1) Amaç
Proje fikri sahibi ile geliştiricileri **yetkinlik bazlı** eşleştirmek; eşleşen ekibe AI destekli proje yönetimi (WBS/Sprint/Gantt/görev dağıtımı) sağlamak; proje sonunda 360° değerlendirmelerle profil skoru üretmek.

### 2) Roller
- **Fikir Sahibi (İlan Sahibi)**: İlan oluşturur, adayları görür, takım kurar.
- **Geliştirici**: Profil/yetkinliklerini girer, eşleşme bildirimi alır, takıma katılır, görev alır.
- **Admin** (MVP’de opsiyonel): İçerik/rapor/ayar yönetimi.

### 3) MVP Kullanıcı Hikayeleri
- **Auth**
  - Kullanıcı kayıt olur / giriş yapar.
- **Profil**
  - Geliştirici; yetkinliklerini (serbest metin + seçilebilir tag) ve deneyim seviyesini girer.
- **İlan**
  - Fikir sahibi; proje açıklaması + aranan yetkinlikleri serbest metinle girerek ilan yayınlar.
  - Sistem ilan metninden tag çıkarır.
- **Eşleştirme**
  - Sistem, ilandaki ihtiyaçlara göre uygun geliştiricileri önerir ve bildirim oluşturur.
- **Takım**
  - İlan sahibi takım kurar, geliştiriciler daveti kabul eder.
- **AI Scrum Master**
  - Sistem proje metninden WBS/backlog çıkarır, sprintlere böler, görevleri profillere göre dağıtır.
  - Gantt verisi üretir (görselleştirme sonraki adım).
- **Değerlendirme**
  - Proje sonunda üyeler 360° değerlendirme formu doldurur.
  - Sistem NLP ile analiz edip profil skorunu günceller.

### 4) MVP Dışı (Faz-2)
- Gerçek zamanlı chat, ödeme/escrow, gerçek push notification altyapısı (FCM/APNS), gelişmiş admin paneli.

### 5) Fonksiyonel Olmayan Gereksinimler
- **Güvenlik**: JWT, temel rate limit (ileride), input validation.
- **İzlenebilirlik**: Basit audit trail (kim ne yaptı) (MVP’de minimal).
- **Performans**: Eşleştirme sorguları hızlı (MVP’de top-k).
- **Maliyet**: NLP işlemlerinde cache/batch stratejisi (10. hafta B planı ile uyumlu).

