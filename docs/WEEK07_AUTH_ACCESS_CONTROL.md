## Week 7 - Auth Zorunluluğu (Web + Mobil)

### Hedef
Kullanıcı giriş yapmadan uygulama ekranlarına erişememeli.

### Web tarafı (tamamlandı)
- `web/login.html`: giriş ekranı
- `web/register.html`: kayıt ekranı
- `web/auth.js`: token saklama, route guard, logout yardımcıları
- `web/index.html` ve `web/matchmaking.html`: token yoksa `login.html`'e redirect

### Mobil tarafı (uygulanacak kural)
Mobil uygulama Flutter ile açıldığında ilk kontrol:
1. Local storage'dan access token oku
2. Token varsa ana uygulama sayfasına geç
3. Token yoksa login/register ekranlarını göster
4. Logout işleminde token'ı sil ve login ekranına dön

### API güvenliği
Backend tarafında auth dışındaki çekirdek endpoint'ler JWT korumalıdır:
- `/api/me/*`
- `/api/skills/*`
- `/api/project-posts/*`
- `/api/health/milvus/`
- `/api/nlp/extract-tags/`

Bu nedenle mobil tarafta da token olmadan bu endpoint'lere erişim yoktur.
