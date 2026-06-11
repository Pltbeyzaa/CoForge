## CoForge — User Flow (MVP)

### Akış 1: İlan oluşturma → tag çıkarımı → eşleştirme bildirimi
1. Fikir sahibi giriş yapar
2. “Yeni İlan” formuna proje metnini yazar
3. Sistem:
   - metinden yetkinlik tag’leri çıkarır
   - ilanı kaydeder
4. Sistem eşleştirme çalıştırır:
   - uygun geliştiricileri bulur (MVP: keyword; hedef: Milvus semantic)
   - bildirim kaydı oluşturur

### Akış 2: Davet → takım kurma
1. Geliştirici bildirim listesini görür
2. “İlgileniyorum / Katıl” aksiyonunu verir
3. İlan sahibi adayları görür ve takımı finalize eder

### Akış 3: AI Scrum Master → WBS/Sprint/Görev dağıtımı
1. Takım kurulduktan sonra “Plan oluştur” tetiklenir
2. Sistem:
   - WBS/backlog üretir
   - sprint planı çıkarır
   - görevi kişilere atar
   - Gantt verisini üretir
3. Takım “taslak” planı onaylar (Risk-2 B planı)

### Akış 4: Proje sonu → 360° değerlendirme → skor
1. Proje bitişinde üyeler birbirini değerlendirir
2. Sistem metinleri analiz eder
3. Profil “Başarı/Güven” skorları güncellenir

