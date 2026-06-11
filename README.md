## CoForge

CoForge; proje fikri olan kişilerin ilan açtığı, uygun yetkinlikteki geliştiricilerin yapay zeka ile eşleştirildiği ve ekip kurulduktan sonra otonom bir **AI Scrum Master** ile sprint/WBS/Gantt/görev dağılımı üreten uçtan uca bir platformdur.

---

### Modüller
- **İlan + NLP**: Serbest metinden yetkinlik etiketleri (tag) çıkarımı.
- **Matchmaking**: İlan ihtiyaçları ile geliştirici profillerinin semantik eşleştirilmesi.
- **Otonom AI Scrum Master**: WBS, sprint planı, görev dağıtımı ve Gantt diyagramı üretimi.
- **Güvenilirlik**: 360° değerlendirme analizi ile başarı ve güven skoru hesaplama.

---

### 🛠️ Kullanılan Teknolojiler (Tech Stack)

Projenin mimarisi, ölçeklenebilir ve yapay zeka odaklı modern teknolojiler üzerine kurulmuştur:

* **Backend:** Python, Django, Django REST Framework (DRF) 
* **Veritabanı:** MySQL (İlişkisel), Milvus (Vektörel), SQLite 
* **Yapay Zeka & NLP:** OpenAI API (GPT-4), spaCy 
* **Frontend:** HTML5, CSS3, JavaScript, Flutter 
* **DevOps & Dağıtım:** Docker, Nginx, Gunicorn, Git/GitHub 

---

### Repo Yapısı (Monorepo)
- `backend/`: Django + DRF API altyapısı.
- `infra/`: Docker Compose (MySQL, Milvus vb.) servisleri.
- `web/`: HTML/CSS/JS — **frontend entegrasyon paneli** (`matchmaking.html`) ile auth + ilan + NLP + eşleşme akışı çalışır durumda.

---

## 🗓️ 11 Haftalık İş Paketleri (Sprint Takvimi)

Aşağıdaki tablo, projenin Çevik (Agile) geliştirme sürecindeki haftalık hedeflerini göstermektedir. *(Test süreçleri 3. haftadan itibaren her pakete entegre edilmiştir.)*

| Hafta | Durum | İş Paketi (Kapsam) | Görevler / Detaylar |
| :---: | :---: | :--- | :--- |
| **1** | ✅ Bitti | **Sistem Analizi ve Tasarım** | • Gereksinim analizi dokümanının hazırlanması.<br>• Mobil ve web arayüz (UI/UX) taslaklarının çizilmesi. |
| **2** | ✅ Bitti | **Veritabanı Mimari Kurulumu** | • MySQL ER diyagramlarının ve tablo ilişkilerinin tasarımı.<br>• Veritabanı şemasının kodlamaya hazır hale getirilmesi. |
| **3** | ✅ Bitti | **Core Backend & REST API** | • Django projesinin başlatılması ve MySQL bağlantısı.<br>• JWT tabanlı Auth (Kayıt/Giriş) sisteminin yazılması. |
| **4** | ✅ Bitti | **Backend & Vektör DB** | • Django REST Framework (DRF) endpoint'lerinin tamamlanması.<br>• Milvus vektör veritabanının projeye entegre edilmesi. |
| **5** | ✅ Bitti | **NLP & Akıllı Eşleştirme** | • OpenAI API/spaCy ile metinden yetkinlik çıkarımı.<br>• Çıkarılan yetkinliklerin vektörleştirilmesi. |
| **6** | ✅ Bitti | **Eşleşme Motoru & Web** | • Milvus benzerlik araması ile matchmaking algoritması.<br>• Web paneli (HTML/CSS/JS) iskeletinin oluşturulması. |
| **7** | ✅ Bitti | **Mobil & Web Frontend** | • Web arayüzünde auth + skill + proje ilanı + NLP analiz + eşleşme akışı tek panelde birleştirildi.<br>• API'lerin web arayüzüne entegrasyonu tamamlandı; mobil ekran çalışmaları bir sonraki iterasyonda derinleştirilecek. |
| **8** | ✅ Bitti | **AI Scrum Master Modülü** | • AI ile ilan metninden otomatik WBS ve Backlog üretimi.<br>• Görev dağıtımını sağlayan prompt mühendisliği çalışmaları. |
| **9** | ✅ Bitti | **Sprint & Değerlendirme** | • Görevlerin haftalık Sprint ve Gantt formatına dökülmesi.<br>• 360 derece değerlendirme formu altyapısının yazılması. |
| **10** | ✅ Bitti | **Puanlama & Test Süreci** | • NLP ile geri bildirimlerden "Güvenilirlik Skoru" üretimi.<br>• Uçtan uca sistem testleri ve hata (bug) raporlaması. |
| **11** | ✅ Bitti | **Canlıya Alma (Deployment)** | • Projenin Docker ile konteynerize edilmesi.<br>• Nginx ve Gunicorn ile canlı sunucu kurulumu. |

---

### 📚 Dokümantasyon
- Haftalık plan detayı: `docs/HAFTALIK_IS_PAKETI_PLANI.md`
- Gereksinim analizi: `docs/GEREKSINIMLER.md`
- User flow: `docs/USER_FLOW.md`
- Week 7 auth erişim kuralı: `docs/WEEK07_AUTH_ACCESS_CONTROL.md`
- ER diyagramı: `docs/ER_DIAGRAMI.md`
- 4. hafta API özeti: `docs/WEEK04_API.md`
- 6. hafta API özeti: `docs/WEEK06_API.md`

### 🗄️ Veritabanı Şeması (MySQL Taslağı)
- MySQL şema taslağı: `backend/db/schema_mysql_draft.sql`  
  (Django modelleri `accounts` + `core` uygulamalarında; migrate ile MySQL’e yansır.)

### 🛠️ Yerelde Çalıştırma
1. `infra/docker-compose.yml` ile servisleri başlat.
2. `backend/` dizininden Django API'yi çalıştır.
3. **Göstermelik ana sayfa:** `web/` klasöründe `python -m http.server 5500` → tarayıcıda `http://127.0.0.1:5500/`

> **Geliştirici:** CoForge Team

---