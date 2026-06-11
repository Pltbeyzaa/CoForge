"""
Co-Forge — TF-IDF eşleşme testi için veritabanı doldurma scripti.

Kullanım (iki yöntemden biri):
    cd backend
    python manage.py shell < seed_db.py          # yöntem 1
    python seed_db.py                             # yöntem 2 (Django otomatik başlatılır)

İdempotent: tekrar çalıştırılırsa mevcut kayıtları atlar,
sadece eksik olanları ekler.
"""

import os
import sys
import django

# ── manage.py shell dışında çalıştırılırsa Django'yu başlat ──────────────────
if not os.environ.get("DJANGO_SETTINGS_MODULE"):
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "coforge_backend.settings")
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    django.setup()

from django.contrib.auth import get_user_model
from core.models import (
    DeveloperProfile,
    Skill,
    UserSkill,
    ProjectPost,
    ProjectRequiredSkill,
)

User = get_user_model()

# ─────────────────────────────────────────────────────────────────────────────
# YARDIMCI FONKSİYONLAR
# ─────────────────────────────────────────────────────────────────────────────

def get_skill(name, category=""):
    obj, _ = Skill.objects.get_or_create(name=name, defaults={"category": category})
    return obj


def make_user(email, full_name, password="CoForge2024!"):
    u, created = User.objects.get_or_create(
        email=email,
        defaults={"full_name": full_name, "role": User.ROLE_DEVELOPER, "is_active": True},
    )
    if created:
        u.set_password(password)
        u.save()
    return u


def make_profile(user, title, bio, github, linkedin, level, years, location):
    p, _ = DeveloperProfile.objects.get_or_create(user=user)
    p.title = title
    p.bio = bio
    p.github_url = github
    p.linkedin_url = linkedin
    p.experience_level = level
    p.years_experience = years
    p.location = location
    p.is_open_to_projects = True
    p.save()
    return p


def assign_skills(profile, skill_tuples):
    """skill_tuples: [(name, category, level), ...]"""
    for name, cat, lvl in skill_tuples:
        s = get_skill(name, cat)
        UserSkill.objects.get_or_create(
            profile=profile, skill=s, defaults={"level": lvl}
        )


def make_project(owner_user, title, description, skill_names, max_team=4):
    p, _ = ProjectPost.objects.get_or_create(
        owner=owner_user,
        title=title,
        defaults={
            "description": description,
            "status": ProjectPost.Status.OPEN,
            "max_team_size": max_team,
        },
    )
    for i, (sname, scat) in enumerate(skill_names):
        s = get_skill(sname, scat)
        ProjectRequiredSkill.objects.get_or_create(
            project=p, skill=s, defaults={"priority": i + 1}
        )
    return p


# ─────────────────────────────────────────────────────────────────────────────
# 1. GELİŞTİRİCİLER  (20 kişi, 6 farklı alan)
# ─────────────────────────────────────────────────────────────────────────────
print("→ [1/3] Geliştiriciler oluşturuluyor...")

DEVELOPERS = [

    # ═══════════════════════════════════════════════════════════════
    # MOBİL  (Flutter · Swift · Kotlin · React Native)
    # ═══════════════════════════════════════════════════════════════
    {
        "email": "ayse.kaya@coforge.dev", "full_name": "Ayşe Kaya",
        "title": "Senior Flutter Developer",
        "bio": (
            "4 yıldır Flutter ile iOS ve Android için cross-platform uygulamalar "
            "geliştiriyorum. BLoC ve Riverpod state management, Firebase Firestore ile "
            "gerçek zamanlı veri senkronizasyonu konularında uzmanım. E-ticaret ve "
            "sağlık sektörü için 10'dan fazla uygulamayı App Store ve Google Play'e "
            "taşıdım; performans optimizasyonu ve clean architecture benim önceliğim."
        ),
        "github": "https://github.com/aysekaya-dev",
        "linkedin": "https://linkedin.com/in/ayse-kaya-flutter",
        "level": "senior", "years": 4, "location": "İstanbul",
        "skills": [
            ("Flutter", "Mobile", "expert"),
            ("Dart", "Mobile", "expert"),
            ("Firebase", "Backend", "advanced"),
            ("REST API", "Backend", "advanced"),
            ("Git", "General", "advanced"),
        ],
    },
    {
        "email": "fatma.ozturk@coforge.dev", "full_name": "Fatma Öztürk",
        "title": "iOS Developer — SwiftUI & HealthKit",
        "bio": (
            "Swift ve SwiftUI ile sağlık ve wellness odaklı iOS uygulamaları "
            "geliştiriyorum. HealthKit ve CoreData entegrasyonlarında deneyimliyim; "
            "App Store'da toplam 150K indirme yapmış 3 uygulamam yayında. "
            "Kullanıcı odaklı tasarım anlayışım ve A/B test alışkanlığımla "
            "dönüşüm oranlarını tutarlı biçimde artırıyorum."
        ),
        "github": "https://github.com/fatmaozturk-ios",
        "linkedin": "https://linkedin.com/in/fatma-ozturk-ios",
        "level": "mid", "years": 3, "location": "Ankara",
        "skills": [
            ("Swift", "Mobile", "expert"),
            ("Firebase", "Backend", "intermediate"),
            ("REST API", "Backend", "advanced"),
            ("Git", "General", "advanced"),
            ("Machine Learning", "AI", "beginner"),
        ],
    },
    {
        "email": "hasan.yildiz@coforge.dev", "full_name": "Hasan Yıldız",
        "title": "Android & Kotlin Developer",
        "bio": (
            "Kotlin ve Jetpack Compose ile modern Android uygulamaları geliştiriyorum. "
            "MVVM + Clean Architecture, Room veritabanı ve Retrofit konularında "
            "derinlemesine bilgiye sahibim. GitHub'da 300+ yıldız toplamış açık kaynak "
            "kütüphanelerim var; offline-first yaklaşımı ve test coverage benim imzam."
        ),
        "github": "https://github.com/hasanyildiz-android",
        "linkedin": "https://linkedin.com/in/hasan-yildiz-android",
        "level": "mid", "years": 2, "location": "İzmir",
        "skills": [
            ("Kotlin", "Mobile", "expert"),
            ("Firebase", "Backend", "intermediate"),
            ("REST API", "Backend", "advanced"),
            ("Docker", "DevOps", "beginner"),
            ("Git", "General", "advanced"),
        ],
    },
    {
        "email": "gul.karahan@coforge.dev", "full_name": "Gül Karahan",
        "title": "React Native Developer",
        "bio": (
            "React Native ve Expo ile iOS/Android uygulamaları üretiyorum. "
            "Redux Toolkit ve React Query ile karmaşık state yönetimini sadeleştiriyor, "
            "Reanimated 3 ile akıcı animasyonlar tasarlıyorum. Startup ortamlarında "
            "hızlı prototipleme tecrübesi sayesinde hem MVP hem de ölçeklenebilir "
            "mimari arasında doğru dengeyi kurabiliyorum."
        ),
        "github": "https://github.com/gulkarahan-rn",
        "linkedin": "https://linkedin.com/in/gul-karahan",
        "level": "mid", "years": 3, "location": "İstanbul",
        "skills": [
            ("React Native", "Mobile", "expert"),
            ("TypeScript", "Frontend", "advanced"),
            ("Node.js", "Backend", "intermediate"),
            ("Firebase", "Backend", "intermediate"),
            ("Git", "General", "advanced"),
        ],
    },

    # ═══════════════════════════════════════════════════════════════
    # FRONTEND  (React · Vue · Next.js · TypeScript)
    # ═══════════════════════════════════════════════════════════════
    {
        "email": "mehmet.yilmaz@coforge.dev", "full_name": "Mehmet Yılmaz",
        "title": "Senior React & Next.js Developer",
        "bio": (
            "React ve TypeScript ekosisteminde 5 yıllık deneyimim var. "
            "Next.js App Router ile SSR/SSG mimarileri, GraphQL ile esnek veri "
            "yönetimi ve Tailwind CSS ile pixel-perfect arayüzler oluşturuyorum. "
            "Büyük ölçekli SaaS ürünlerinde frontend mimari kararları aldım; "
            "Web Vitals optimizasyonunda ölçülebilir sonuçlar elde ettim."
        ),
        "github": "https://github.com/mehmetyilmaz-ui",
        "linkedin": "https://linkedin.com/in/mehmet-yilmaz-react",
        "level": "senior", "years": 5, "location": "İstanbul",
        "skills": [
            ("React", "Frontend", "expert"),
            ("TypeScript", "Frontend", "expert"),
            ("Next.js", "Frontend", "expert"),
            ("GraphQL", "Backend", "advanced"),
            ("Tailwind CSS", "Frontend", "advanced"),
        ],
    },
    {
        "email": "leyla.gunes@coforge.dev", "full_name": "Leyla Güneş",
        "title": "Vue.js & Nuxt Developer",
        "bio": (
            "Vue 3 Composition API ve Nuxt.js ile kurumsal web uygulamaları "
            "geliştiriyorum. Pinia ile state yönetimi, Vuetify ile erişilebilir "
            "komponent kütüphanesi ve i18n ile çok dilli uygulama konularında "
            "deneyimliyim. E-öğrenme ve fintech sektörlerinde 4 yıllık tecrübem var."
        ),
        "github": "https://github.com/leylagunes-vue",
        "linkedin": "https://linkedin.com/in/leyla-gunes",
        "level": "mid", "years": 4, "location": "Bursa",
        "skills": [
            ("Vue.js", "Frontend", "expert"),
            ("TypeScript", "Frontend", "advanced"),
            ("REST API", "Backend", "advanced"),
            ("HTML/CSS", "Frontend", "expert"),
            ("Node.js", "Backend", "intermediate"),
        ],
    },
    {
        "email": "cansu.guler@coforge.dev", "full_name": "Cansu Güler",
        "title": "Full-Stack Next.js Developer",
        "bio": (
            "Next.js ve Django kombinasyonuyla full-stack uygulamalar geliştiriyorum. "
            "Vercel deployments, Prisma ORM ve Tailwind CSS ile hızlı ve ölçeklenebilir "
            "web servisleri üretiyorum. Açık kaynak katkısını önemsiyorum; "
            "birkaç popüler Next.js starter projesine pull request göndermiş durumdayım."
        ),
        "github": "https://github.com/cansuguler",
        "linkedin": "https://linkedin.com/in/cansu-guler-dev",
        "level": "mid", "years": 3, "location": "İzmir",
        "skills": [
            ("Next.js", "Frontend", "expert"),
            ("React", "Frontend", "advanced"),
            ("TypeScript", "Frontend", "advanced"),
            ("Django", "Backend", "intermediate"),
            ("Tailwind CSS", "Frontend", "advanced"),
        ],
    },

    # ═══════════════════════════════════════════════════════════════
    # BACKEND  (Django · Node.js · FastAPI · PostgreSQL)
    # ═══════════════════════════════════════════════════════════════
    {
        "email": "zeynep.demir@coforge.dev", "full_name": "Zeynep Demir",
        "title": "Senior Django & Python Developer",
        "bio": (
            "Django REST Framework ve PostgreSQL ile yüksek trafikli API'lar tasarlıyorum. "
            "Celery + Redis ile asenkron task yönetimi, Docker Compose ile geliştirme "
            "ortamı standardizasyonu konularında uzmanım. Fintech şirketlerinde "
            "ödeme gateway entegrasyonları ve PCI-DSS uyumlu backend mimarisi üzerine çalıştım."
        ),
        "github": "https://github.com/zeynepdemir-backend",
        "linkedin": "https://linkedin.com/in/zeynep-demir-django",
        "level": "senior", "years": 6, "location": "Ankara",
        "skills": [
            ("Django", "Backend", "expert"),
            ("Python", "Backend", "expert"),
            ("PostgreSQL", "Backend", "expert"),
            ("Redis", "Backend", "advanced"),
            ("Docker", "DevOps", "advanced"),
        ],
    },
    {
        "email": "burak.sahin@coforge.dev", "full_name": "Burak Şahin",
        "title": "Node.js & Express Developer",
        "bio": (
            "Node.js, Express ve MongoDB ile ölçeklenebilir backend servisleri "
            "geliştiriyorum. Socket.io ile gerçek zamanlı uygulamalar, JWT ve "
            "OAuth2 ile güvenli kimlik doğrulama, BullMQ ile kuyruk yönetimi "
            "konularında deneyimliyim. Mikroservis geçişlerinde mimari rehberlik yaptım."
        ),
        "github": "https://github.com/buraksahin-node",
        "linkedin": "https://linkedin.com/in/burak-sahin-nodejs",
        "level": "mid", "years": 4, "location": "İstanbul",
        "skills": [
            ("Node.js", "Backend", "expert"),
            ("MongoDB", "Backend", "advanced"),
            ("Socket.io", "Backend", "advanced"),
            ("REST API", "Backend", "expert"),
            ("Docker", "DevOps", "intermediate"),
        ],
    },
    {
        "email": "derya.polat@coforge.dev", "full_name": "Derya Polat",
        "title": "FastAPI & Microservices Developer",
        "bio": (
            "FastAPI ve async Python ile yüksek performanslı mikroservisler "
            "geliştiriyorum. Redis ile dağıtık cache, Pydantic ile veri doğrulama "
            "ve Alembic ile migration yönetimi konularında uzmanlaştım. "
            "API güvenliği, rate limiting ve OpenTelemetry ile distributed tracing "
            "konularında canlı ortam deneyimim var."
        ),
        "github": "https://github.com/deryapolat-api",
        "linkedin": "https://linkedin.com/in/derya-polat",
        "level": "mid", "years": 3, "location": "İstanbul",
        "skills": [
            ("FastAPI", "Backend", "expert"),
            ("Python", "Backend", "expert"),
            ("Docker", "DevOps", "advanced"),
            ("Redis", "Backend", "advanced"),
            ("PostgreSQL", "Backend", "advanced"),
        ],
    },
    {
        "email": "tarik.bulut@coforge.dev", "full_name": "Tarık Bulut",
        "title": "Backend & Database Specialist",
        "bio": (
            "PostgreSQL query optimizasyonu, partitioning ve logical replication "
            "konularında uzmanım. Django ve FastAPI ile data-intensive uygulamalar "
            "tasarlıyorum; TimescaleDB ile zaman serisi veri mimarisi ve "
            "Elasticsearch ile full-text arama entegrasyonlarında canlı ortam "
            "deneyimim bulunuyor."
        ),
        "github": "https://github.com/tarikbulut-db",
        "linkedin": "https://linkedin.com/in/tarik-bulut-db",
        "level": "senior", "years": 5, "location": "Ankara",
        "skills": [
            ("PostgreSQL", "Backend", "expert"),
            ("Django", "Backend", "advanced"),
            ("Python", "Backend", "expert"),
            ("Redis", "Backend", "advanced"),
            ("Linux", "DevOps", "advanced"),
        ],
    },
    {
        "email": "mustafa.korkmaz@coforge.dev", "full_name": "Mustafa Korkmaz",
        "title": "Full-Stack Developer — React & Django",
        "bio": (
            "React frontend ve Django REST backend ile uçtan uca uygulamalar "
            "geliştiriyorum. GraphQL ile esnek veri sorgulama, Celery ile "
            "background task yönetimi ve Jest + Pytest ile otomatik test kapsama "
            "konularında deneyimliyim. Startup ortamlarında hızlı iterasyona alışkınım."
        ),
        "github": "https://github.com/mustafakorkmaz",
        "linkedin": "https://linkedin.com/in/mustafa-korkmaz-dev",
        "level": "mid", "years": 3, "location": "İstanbul",
        "skills": [
            ("React", "Frontend", "advanced"),
            ("Django", "Backend", "advanced"),
            ("Python", "Backend", "advanced"),
            ("PostgreSQL", "Backend", "intermediate"),
            ("GraphQL", "Backend", "intermediate"),
        ],
    },

    # ═══════════════════════════════════════════════════════════════
    # YAPAY ZEKA / ML  (PyTorch · NLP · TensorFlow · Veri Bilimi)
    # ═══════════════════════════════════════════════════════════════
    {
        "email": "ali.celik@coforge.dev", "full_name": "Ali Çelik",
        "title": "AI/ML Research Engineer",
        "bio": (
            "PyTorch ve HuggingFace Transformers ile derin öğrenme modelleri "
            "geliştirip fine-tune ediyorum. NLP, öneri sistemleri ve LLM tabanlı "
            "uygulama alanlarında araştırmalarım var; 3 hakemli yayın ve 2 konferans "
            "sunumum bulunuyor. LangChain ve RAG pipeline mimarisi konusunda da "
            "aktif olarak çalışıyorum."
        ),
        "github": "https://github.com/alicelik-ai",
        "linkedin": "https://linkedin.com/in/ali-celik-ml",
        "level": "senior", "years": 5, "location": "Ankara",
        "skills": [
            ("Python", "Backend", "expert"),
            ("PyTorch", "AI", "expert"),
            ("NLP", "AI", "expert"),
            ("Machine Learning", "AI", "expert"),
            ("Transformers", "AI", "advanced"),
        ],
    },
    {
        "email": "selin.arslan@coforge.dev", "full_name": "Selin Arslan",
        "title": "Data Scientist",
        "bio": (
            "Pandas, NumPy ve Scikit-learn ile veri analizi ve makine öğrenmesi "
            "modelleri geliştiriyorum. A/B testi, istatistiksel analiz ve Plotly "
            "ile etkileşimli görselleştirme konularında uzmanım. Büyük veri için "
            "PySpark kullanan pipeline'lar kurdum; müşteri segmentasyonu ve "
            "churn prediction projelerinde ölçülebilir iş etkisi yarattım."
        ),
        "github": "https://github.com/selinarslan-data",
        "linkedin": "https://linkedin.com/in/selin-arslan-ds",
        "level": "mid", "years": 4, "location": "İzmir",
        "skills": [
            ("Python", "Backend", "expert"),
            ("Pandas", "Data", "expert"),
            ("NumPy", "Data", "expert"),
            ("Scikit-learn", "AI", "advanced"),
            ("Spark", "Data", "intermediate"),
        ],
    },
    {
        "email": "emre.ozkan@coforge.dev", "full_name": "Emre Özkan",
        "title": "NLP Engineer",
        "bio": (
            "Transformers mimarisi ve BERT türevi modellerle Türkçe NLP üzerine "
            "uzmanlaştım. Metin sınıflandırma, NER, soru-cevap ve özetleme "
            "projelerinde uçtan uca model eğitimi gerçekleştirdim. LangChain ve "
            "pgvector/Milvus ile RAG sistemleri kuruyorum; FastAPI ile model "
            "servis katmanı ve API tasarımı konusunda da deneyimliyim."
        ),
        "github": "https://github.com/emreozkan-nlp",
        "linkedin": "https://linkedin.com/in/emre-ozkan-nlp",
        "level": "mid", "years": 3, "location": "İstanbul",
        "skills": [
            ("Python", "Backend", "expert"),
            ("NLP", "AI", "expert"),
            ("PyTorch", "AI", "advanced"),
            ("Transformers", "AI", "expert"),
            ("FastAPI", "Backend", "intermediate"),
        ],
    },
    {
        "email": "tolga.acar@coforge.dev", "full_name": "Tolga Acar",
        "title": "Computer Vision Engineer",
        "bio": (
            "OpenCV ve TensorFlow ile gerçek zamanlı görüntü işleme sistemleri "
            "geliştiriyorum. YOLO v8 ile nesne tespiti, ByteTrack ile çok nesne "
            "takibi ve segmentasyon modelleri konularında uzmanlaştım. "
            "Fabrika otomasyonu ve medikal görüntüleme projelerinde GPU-optimize "
            "inference pipeline'ları kurdum."
        ),
        "github": "https://github.com/tolgaacar-cv",
        "linkedin": "https://linkedin.com/in/tolga-acar-cv",
        "level": "mid", "years": 3, "location": "İstanbul",
        "skills": [
            ("Python", "Backend", "expert"),
            ("OpenCV", "AI", "expert"),
            ("TensorFlow", "AI", "advanced"),
            ("NumPy", "Data", "advanced"),
            ("Docker", "DevOps", "intermediate"),
        ],
    },

    # ═══════════════════════════════════════════════════════════════
    # OYUN GELİŞTİRME  (Unity · C# · Unreal · C++)
    # ═══════════════════════════════════════════════════════════════
    {
        "email": "oguz.erdogan@coforge.dev", "full_name": "Oğuz Erdoğan",
        "title": "Senior Unity Game Developer",
        "bio": (
            "Unity3D ve C# ile mobil ve PC oyunları geliştiriyorum. "
            "Fizik motoru optimizasyonu, custom shader programlama ve Photon "
            "Fusion ile multiplayer sistemler kuruyorum. App Store ve Google "
            "Play'de toplam 600K+ indirme alan 5 oyun yayınladım; oyun ekonomisi "
            "ve monetizasyon tasarımı konusunda da deneyimliyim."
        ),
        "github": "https://github.com/oguzerdogan-games",
        "linkedin": "https://linkedin.com/in/oguz-erdogan-unity",
        "level": "senior", "years": 5, "location": "İstanbul",
        "skills": [
            ("Unity", "GameDev", "expert"),
            ("C#", "GameDev", "expert"),
            ("Shader Programming", "GameDev", "advanced"),
            ("Firebase", "Backend", "intermediate"),
            ("Git", "General", "advanced"),
        ],
    },
    {
        "email": "serhat.tekin@coforge.dev", "full_name": "Serhat Tekin",
        "title": "Unreal Engine & C++ Developer",
        "bio": (
            "Unreal Engine 5 ile AAA kalitesinde oyun prototipleri geliştiriyorum. "
            "Nanite, Lumen ve Chaos Physics gibi UE5 teknolojilerini canlı "
            "projelerde kullandım. Oyun sunucu mimarisi, dedicated server kurulumu "
            "ve anti-cheat mekanizmaları konusunda da bilgi sahibiyim. "
            "Indie stüdyolarda lider geliştirici olarak çalıştım."
        ),
        "github": "https://github.com/serhattekin-gamedev",
        "linkedin": "https://linkedin.com/in/serhat-tekin",
        "level": "mid", "years": 4, "location": "Ankara",
        "skills": [
            ("C++", "GameDev", "expert"),
            ("Unreal Engine", "GameDev", "expert"),
            ("C#", "GameDev", "intermediate"),
            ("Shader Programming", "GameDev", "intermediate"),
            ("Git", "General", "advanced"),
        ],
    },

    # ═══════════════════════════════════════════════════════════════
    # DEVOPS / CLOUD  (Docker · Kubernetes · AWS · GCP)
    # ═══════════════════════════════════════════════════════════════
    {
        "email": "elif.aydin@coforge.dev", "full_name": "Elif Aydın",
        "title": "Senior DevOps & Cloud Engineer",
        "bio": (
            "Docker, Kubernetes ve Terraform ile bulut altyapısı kuruyorum. "
            "AWS (ECS, RDS, Lambda, S3) ve GCP üzerinde production ortamları "
            "yönetiyorum; GitHub Actions ile CI/CD pipeline tasarımı ve "
            "Argo CD ile GitOps implementasyonu konularında uzmanım. "
            "SRE pratiklerini benimseyerek servis güvenilirliğini %99.9'un üzerine çıkardım."
        ),
        "github": "https://github.com/elifaydin-devops",
        "linkedin": "https://linkedin.com/in/elif-aydin-devops",
        "level": "senior", "years": 5, "location": "İstanbul",
        "skills": [
            ("Docker", "DevOps", "expert"),
            ("Kubernetes", "DevOps", "expert"),
            ("AWS", "DevOps", "expert"),
            ("GitHub Actions", "DevOps", "advanced"),
            ("Terraform", "DevOps", "advanced"),
        ],
    },
    {
        "email": "meryem.dogan@coforge.dev", "full_name": "Meryem Doğan",
        "title": "Cloud & Infrastructure Engineer",
        "bio": (
            "GCP ve AWS'de container tabanlı mimariler kuruyorum. Kubernetes "
            "cluster yönetimi, Helm chart geliştirme ve Prometheus + Grafana ile "
            "gözlemlenebilirlik stack kurulumu konularında deneyimliyim. "
            "Linux sistem yönetimi ve network güvenliği benim temel uzmanlık alanlarım; "
            "incident response süreçlerinde aktif rol aldım."
        ),
        "github": "https://github.com/meryemdogan-cloud",
        "linkedin": "https://linkedin.com/in/meryem-dogan-cloud",
        "level": "mid", "years": 4, "location": "İzmir",
        "skills": [
            ("Docker", "DevOps", "expert"),
            ("GCP", "DevOps", "advanced"),
            ("Kubernetes", "DevOps", "advanced"),
            ("Linux", "DevOps", "expert"),
            ("GitHub Actions", "DevOps", "advanced"),
        ],
    },
]

profiles_by_email = {}
for dev in DEVELOPERS:
    u = make_user(dev["email"], dev["full_name"])
    p = make_profile(
        user=u,
        title=dev["title"], bio=dev["bio"],
        github=dev["github"], linkedin=dev["linkedin"],
        level=dev["level"], years=dev["years"], location=dev["location"],
    )
    assign_skills(p, dev["skills"])
    profiles_by_email[dev["email"]] = p

print(f"   ✓ {len(DEVELOPERS)} geliştirici işlendi.")


# ─────────────────────────────────────────────────────────────────────────────
# 2. PROJE İLANLARI  (20 proje, 6 farklı alan)
# ─────────────────────────────────────────────────────────────────────────────
print("→ [2/3] Proje ilanları oluşturuluyor...")

PROJECTS = [

    # ═══════════════ MOBİL ═══════════════════════════════════════════════════
    {
        "owner": "ayse.kaya@coforge.dev",
        "title": "Flutter ile P2P Pazar Yeri Uygulaması",
        "description": (
            "Bireyler arası ürün alım-satımı için cross-platform bir pazar yeri "
            "uygulaması geliştiriyoruz. Firebase Firestore ile gerçek zamanlı "
            "mesajlaşma, Stripe entegrasyonu ile güvenli ödeme ve Google Maps SDK "
            "ile yakın konum filtreleme özelliklerini hayata geçireceğiz. "
            "BLoC state management ve Clean Architecture prensipleriyle tasarlanan "
            "uygulamanın iOS ve Android'e aynı anda çıkış yapması planlanıyor. "
            "Bildirim sistemi için Firebase Cloud Messaging ve derin bağlantılar (deep link) "
            "için Dynamic Links entegrasyonu da kapsam dahilinde."
        ),
        "skills": [
            ("Flutter", "Mobile"), ("Dart", "Mobile"),
            ("Firebase", "Backend"), ("REST API", "Backend"),
        ],
        "max_team": 3,
    },
    {
        "owner": "fatma.ozturk@coforge.dev",
        "title": "iOS Zihin Sağlığı ve Uyku Takip Uygulaması",
        "description": (
            "Günlük duygu durumu kaydı, uyku kalitesi takibi ve kısa meditasyon "
            "egzersizlerini bir araya getiren bir iOS uygulaması geliştiriyoruz. "
            "HealthKit ile biyometrik verileri analiz edecek, Core ML ile "
            "kişiselleştirilmiş uyku önerisi motoru oluşturacağız. "
            "SwiftUI ile sezgisel ve erişilebilir bir kullanıcı arayüzü hedeflenirken "
            "CloudKit ile cihazlar arası senkronizasyon da sağlanacak. "
            "Uygulama, kullanıcı mahremiyetini ön planda tutacak; veriler öncelikli "
            "olarak cihazda işlenecek."
        ),
        "skills": [
            ("Swift", "Mobile"), ("Firebase", "Backend"),
            ("Machine Learning", "AI"), ("REST API", "Backend"),
        ],
        "max_team": 3,
    },
    {
        "owner": "gul.karahan@coforge.dev",
        "title": "React Native Yemek Sipariş ve Teslimat Platformu",
        "description": (
            "Küçük ve orta ölçekli restoranların bağımsız olarak kullanabileceği "
            "bir yemek sipariş ve teslimat uygulaması geliştiriyoruz. "
            "Expo ile hızlı geliştirme döngüsü, Firebase Firestore ile gerçek "
            "zamanlı sipariş durumu güncelleme ve Stripe ile ödeme işlemleri "
            "hedefleniyor. Kurye konumu için Socket.io tabanlı canlı harita takibi, "
            "restoran paneli için web arayüzü ve analitik rapor ekranı da planlanıyor. "
            "Uygulama çok dilli (Türkçe/İngilizce) olacak."
        ),
        "skills": [
            ("React Native", "Mobile"), ("Firebase", "Backend"),
            ("Node.js", "Backend"), ("Socket.io", "Backend"),
        ],
        "max_team": 4,
    },
    {
        "owner": "hasan.yildiz@coforge.dev",
        "title": "Kotlin ile Kişisel Finans Yönetim Uygulaması",
        "description": (
            "Kullanıcıların bütçe planlaması yapmasını, harcama alışkanlıklarını "
            "analiz etmesini ve tasarruf hedefleri oluşturmasını sağlayan bir "
            "Android uygulaması geliştiriyoruz. Room veritabanı ile offline-first "
            "mimari, Retrofit ile Open Banking API entegrasyonu ve Jetpack Compose "
            "ile modern Material You arayüzü tasarlanacak. ML Kit ile harcama "
            "otomatik kategorizasyonu, widget desteği ve kilit ekranı hızlı bakış "
            "özelliği de eklenmesi planlanıyor."
        ),
        "skills": [
            ("Kotlin", "Mobile"), ("Firebase", "Backend"),
            ("REST API", "Backend"), ("Machine Learning", "AI"),
        ],
        "max_team": 3,
    },

    # ═══════════════ FRONTEND ════════════════════════════════════════════════
    {
        "owner": "mehmet.yilmaz@coforge.dev",
        "title": "React & GraphQL Geliştirici Sosyal Platformu",
        "description": (
            "Geliştiricilerin proje paylaşımı yapabildiği, kod snippet tartışmaları "
            "başlattığı ve mentorluk bağlantısı kurabildiği bir sosyal platform. "
            "Next.js App Router ile sunucu taraflı render, GraphQL subscriptions "
            "ile gerçek zamanlı bildirimler ve Cloudinary ile medya yönetimi "
            "sağlanacak. Tailwind CSS ve Framer Motion ile akıcı animasyonlu "
            "arayüz, Algolia ile gelişmiş içerik arama sistemi de planlanıyor. "
            "GitHub OAuth ile tek tıkla kayıt ve proje otomatik içe aktarım "
            "özelliği kapsam dahilinde."
        ),
        "skills": [
            ("React", "Frontend"), ("TypeScript", "Frontend"),
            ("Next.js", "Frontend"), ("GraphQL", "Backend"),
        ],
        "max_team": 5,
    },
    {
        "owner": "leyla.gunes@coforge.dev",
        "title": "Vue.js Tabanlı Interaktif E-Öğrenme Platformu",
        "description": (
            "Öğretmenlerin kurs oluşturup yönettiği, öğrencilerin video içerikler, "
            "sınavlar ve canlı dersler aracılığıyla öğrendiği bir e-öğrenme sistemi. "
            "Nuxt.js ile SEO-dostu sayfa yapısı, Video.js ile adaptif bitrate video "
            "oynatıcı ve Stripe ile abonelik ve tek seferlik ödeme sistemi entegre "
            "edilecek. Sertifika üretimi, alıştırma motoru ve öğretmen-öğrenci "
            "mesajlaşma sistemi de dahil. Erişilebilirlik (WCAG 2.1 AA) öncelik."
        ),
        "skills": [
            ("Vue.js", "Frontend"), ("TypeScript", "Frontend"),
            ("Node.js", "Backend"), ("PostgreSQL", "Backend"),
        ],
        "max_team": 4,
    },
    {
        "owner": "cansu.guler@coforge.dev",
        "title": "Next.js ile AI Destekli CV ve Portfolyo Builder",
        "description": (
            "Geliştiricilerin sürükle-bırak arayüzüyle kişisel portfolyo sitesi "
            "oluşturabildiği ve OpenAI API ile özgeçmiş özeti otomatik üretilebildiği "
            "bir SaaS platformu geliştiriyoruz. Next.js App Router, Tailwind CSS "
            "ve Shadcn/UI ile kullanıcı arayüzü; Prisma ORM ve PostgreSQL ile "
            "veri katmanı oluşturulacak. GitHub API entegrasyonu ile proje otomatik "
            "içe aktarımı, puppeteer ile PDF export ve özel domain bağlama "
            "özelliği de kapsam dahilinde."
        ),
        "skills": [
            ("Next.js", "Frontend"), ("TypeScript", "Frontend"),
            ("React", "Frontend"), ("PostgreSQL", "Backend"),
        ],
        "max_team": 3,
    },

    # ═══════════════ BACKEND / API ═══════════════════════════════════════════
    {
        "owner": "zeynep.demir@coforge.dev",
        "title": "Django ile Çok Kiracılı SaaS Faturalandırma Sistemi",
        "description": (
            "Abonelik yönetimi, otomatik fatura oluşturma, vergi hesaplaması ve "
            "çoklu para birimi desteği sunan bir faturalandırma mikroservisi "
            "geliştiriyoruz. Django REST Framework ile API katmanı, Celery + Redis "
            "ile zamanlı görevler ve Stripe Billing ile ödeme entegrasyonu "
            "sağlanacak. Multi-tenant mimari, webhook sistemi, PDF fatura oluşturma "
            "ve muhasebe yazılımlarına (e-Fatura) aktarım modülü de planlanıyor. "
            "Tüm servis Docker Compose ile kolayca self-host edilebilecek."
        ),
        "skills": [
            ("Django", "Backend"), ("Python", "Backend"),
            ("PostgreSQL", "Backend"), ("Redis", "Backend"),
        ],
        "max_team": 4,
    },
    {
        "owner": "burak.sahin@coforge.dev",
        "title": "Node.js ile Gerçek Zamanlı Takım İşbirliği Platformu",
        "description": (
            "Ekiplerin aynı anda belge düzenleyebildiği, whiteboard çizebildiği "
            "ve sesli toplantı gerçekleştirebildiği bir işbirliği aracı. "
            "Socket.io ile operasyonel dönüşüm (OT) algoritması, WebRTC ile "
            "P2P ses/video iletişimi ve MongoDB ile belge revizyon geçmişi "
            "saklanacak. Redis pub/sub ile çok sunuculu yük dengeleme ve "
            "çevrimdışı düzenleme + senkronizasyon özelliği de planlanıyor. "
            "Figma ve Notion'a açık kaynak bir alternatif hedefleniyor."
        ),
        "skills": [
            ("Node.js", "Backend"), ("Socket.io", "Backend"),
            ("MongoDB", "Backend"), ("Redis", "Backend"),
        ],
        "max_team": 5,
    },
    {
        "owner": "derya.polat@coforge.dev",
        "title": "FastAPI Tabanlı API Gateway ve Rate Limiter Servisi",
        "description": (
            "Mikroservis mimarilerinde merkezi kimlik doğrulama, yetkilendirme, "
            "rate limiting ve request logging sağlayan hafif bir API gateway. "
            "FastAPI ile yüksek performanslı async request handling, Redis ile "
            "sliding-window rate limiter ve JWT token önbelleği, PostgreSQL ile "
            "audit log depolama planlanıyor. Prometheus ile metrik toplama, "
            "Jaeger ile dağıtık izleme (distributed tracing) ve Helm chart ile "
            "Kubernetes'e kolay dağıtım desteği de kapsam dahilinde."
        ),
        "skills": [
            ("FastAPI", "Backend"), ("Python", "Backend"),
            ("Redis", "Backend"), ("Docker", "DevOps"),
        ],
        "max_team": 3,
    },
    {
        "owner": "tarik.bulut@coforge.dev",
        "title": "PostgreSQL Tabanlı Gerçek Zamanlı Analitik Pano",
        "description": (
            "E-ticaret ve SaaS şirketleri için kullanıcı davranışı, satış trendleri "
            "ve kohort analizleri sunan bir analitik platformu geliştiriyoruz. "
            "TimescaleDB ile zaman serisi verisi, PostgreSQL materialized view ile "
            "hızlı sorgu, Django REST API ile veri servisi ve React + Recharts "
            "ile interaktif grafik panosu oluşturulacak. CSV/Excel export, "
            "e-posta ile zamanlanmış rapor ve alarm eşik bildirimleri de dahil."
        ),
        "skills": [
            ("PostgreSQL", "Backend"), ("Python", "Backend"),
            ("Django", "Backend"), ("React", "Frontend"),
        ],
        "max_team": 4,
    },
    {
        "owner": "mustafa.korkmaz@coforge.dev",
        "title": "Django + React ile Açık Kaynak Proje Yönetim Aracı",
        "description": (
            "Jira ve Linear'a açık kaynaklı bir alternatif geliştiriyoruz. "
            "Scrum board, sprint planlama, backlog yönetimi ve burndown grafikleri "
            "temel özellikler olacak. Django REST API backend, React + TypeScript "
            "frontend ve WebSocket ile gerçek zamanlı kart güncellemeleri sağlanacak. "
            "GitHub entegrasyonu ile commit ve PR bağlantısı, Slack webhook ile "
            "bildirim ve Docker Compose ile self-host seçeneği de planlanıyor."
        ),
        "skills": [
            ("Django", "Backend"), ("React", "Frontend"),
            ("PostgreSQL", "Backend"), ("TypeScript", "Frontend"),
        ],
        "max_team": 5,
    },

    # ═══════════════ YAPAY ZEKA / ML ═════════════════════════════════════════
    {
        "owner": "ali.celik@coforge.dev",
        "title": "PyTorch ile Türkçe NLP Dil Modeli Geliştirme",
        "description": (
            "Türkçe metinler için özelleştirilmiş bir transformer modeli "
            "eğitiyoruz. Duygu analizi, isimlendirilmiş varlık tanıma (NER) "
            "ve soru-cevap görevlerinde SOTA performans hedefliyoruz. "
            "HuggingFace Transformers, PyTorch Lightning ve DVC ile deney "
            "yönetimi kullanılacak. Eğitilen model FastAPI ile REST servisine "
            "dönüştürülecek; ONNX ile optimizasyon ve quantization adımları da "
            "kapsam dahilinde. Kamuya açık Türkçe veri setleri kullanılacak."
        ),
        "skills": [
            ("Python", "Backend"), ("PyTorch", "AI"),
            ("NLP", "AI"), ("Transformers", "AI"),
        ],
        "max_team": 4,
    },
    {
        "owner": "selin.arslan@coforge.dev",
        "title": "Makine Öğrenmesi ile Borsa Sinyal ve Risk Sistemi",
        "description": (
            "Finansal zaman serileri için LSTM, Temporal Fusion Transformer ve "
            "ensemble modeller geliştiriyoruz. Haber duygu analizi ve sosyal medya "
            "verileri ile geleneksel teknik indikatörler birleştirilecek. "
            "Pandas ve NumPy ile özellik mühendisliği, Scikit-learn ile model "
            "karşılaştırması, Airflow ile otomatik yeniden eğitim ve backtesting "
            "pipeline'ı planlanıyor. Sonuçlar interaktif bir Streamlit panosuyla "
            "görselleştirilecek."
        ),
        "skills": [
            ("Python", "Backend"), ("Pandas", "Data"),
            ("Machine Learning", "AI"), ("Scikit-learn", "AI"),
        ],
        "max_team": 3,
    },
    {
        "owner": "emre.ozkan@coforge.dev",
        "title": "RAG Tabanlı Kurumsal Belge Soru-Cevap Sistemi",
        "description": (
            "Kurumsal belge koleksiyonları (PDF, Word, web sayfası) üzerinde "
            "doğal dil ile soru sorulabilen bir sistem geliştiriyoruz. "
            "LangChain ile RAG pipeline, Milvus ile vektör veritabanı, "
            "GPT-4 ile yanıt üretimi ve FastAPI ile servis katmanı planlanıyor. "
            "Belge kaynaklarına bağlantı, alıntı gösterimi ve güven skoru "
            "özelliklerini de içerecek. İnce ayar (fine-tuning) ile şirket "
            "terminolojisine özel adaptasyon adımı da kapsam dahilinde."
        ),
        "skills": [
            ("Python", "Backend"), ("NLP", "AI"),
            ("PyTorch", "AI"), ("FastAPI", "Backend"),
        ],
        "max_team": 4,
    },
    {
        "owner": "tolga.acar@coforge.dev",
        "title": "OpenCV ile Gerçek Zamanlı Güvenlik Kamera Analiz Sistemi",
        "description": (
            "IP kameralardan gelen akışta anomali tespiti, kişi sayımı ve şüpheli "
            "hareket bildirimi yapan bir video analitik sistemi geliştiriyoruz. "
            "YOLO v8 ile nesne tespiti, ByteTrack ile çok nesne takibi ve "
            "TensorFlow ile hareket sınıflandırması kullanılacak. "
            "Sonuçlar WebSocket üzerinden React tabanlı bir canlı pano arayüzüne "
            "aktarılacak. Docker Compose ile tam containerize dağıtım ve isteğe "
            "bağlı GPU desteği planlanıyor."
        ),
        "skills": [
            ("Python", "Backend"), ("OpenCV", "AI"),
            ("TensorFlow", "AI"), ("Docker", "DevOps"),
        ],
        "max_team": 4,
    },

    # ═══════════════ OYUN GELİŞTİRME ═════════════════════════════════════════
    {
        "owner": "oguz.erdogan@coforge.dev",
        "title": "Unity ile Multiplayer Mobil Strateji Oyunu",
        "description": (
            "Gerçek zamanlı PvP bileşenlere sahip, kule savunma ve kaynak "
            "yönetimi mekaniklerini birleştiren bir mobil strateji oyunu. "
            "Photon Fusion ile sunucu taraflı fizik ve otoriter sunucu modeli, "
            "custom HLSL shader'lar ile özel görsel efektler ve Unity Addressables "
            "ile dinamik içerik yükleme sistemi tasarlanacak. "
            "Oyun içi ekonomi dengesi, sezony sistemi ve liderlik tablosu da "
            "kapsam dahilinde. iOS ve Android çıkışı hedefleniyor."
        ),
        "skills": [
            ("Unity", "GameDev"), ("C#", "GameDev"),
            ("Shader Programming", "GameDev"), ("Firebase", "Backend"),
        ],
        "max_team": 4,
    },
    {
        "owner": "serhat.tekin@coforge.dev",
        "title": "Unreal Engine 5 ile Açık Dünya RPG Prototipi",
        "description": (
            "Nanite ve Lumen teknolojilerini kullanan, prosedürel arazi üretimi "
            "ve dinamik hava durumu sistemi içeren bir açık dünya RPG prototipi "
            "geliştiriyoruz. UE5 Blueprint ve C++ ile oyun mekaniği, MetaSounds "
            "ile prosedürel ses sistemi ve Mass Entity ile kalabalık NPC simülasyonu "
            "planlanıyor. Çarpışma sistemi, envanter mekaniği ve diyalog ağacı da "
            "kapsam dahilinde. PC'ye yönelik oynanabilir bir demo sürümü hedefleniyor."
        ),
        "skills": [
            ("C++", "GameDev"), ("Unreal Engine", "GameDev"),
            ("Shader Programming", "GameDev"), ("C#", "GameDev"),
        ],
        "max_team": 5,
    },

    # ═══════════════ DEVOPS / CLOUD ══════════════════════════════════════════
    {
        "owner": "elif.aydin@coforge.dev",
        "title": "Kubernetes Tabanlı Tam Otomatik CI/CD Platformu",
        "description": (
            "GitHub Actions ile tetiklenen; otomatik test, SAST güvenlik taraması "
            "ve progressive delivery uygulayan bir CI/CD platformu geliştiriyoruz. "
            "Argo CD ile GitOps, Kubernetes ile container orchestration, "
            "Istio ile service mesh ve Prometheus + Grafana ile kapsamlı "
            "monitoring stack kurulacak. Helm chart'lar ile multi-cluster "
            "deployment ve Kyverno ile policy-as-code uygulanması da planlanıyor."
        ),
        "skills": [
            ("Docker", "DevOps"), ("Kubernetes", "DevOps"),
            ("AWS", "DevOps"), ("GitHub Actions", "DevOps"),
        ],
        "max_team": 3,
    },
    {
        "owner": "meryem.dogan@coforge.dev",
        "title": "GCP ile IoT Sensör Veri Toplama ve Görselleştirme Platformu",
        "description": (
            "Endüstriyel sensörlerden MQTT protokolü üzerinden veri toplayan, "
            "GCP IoT Core ile işleyen ve Grafana ile görselleştiren bir IoT "
            "platformu geliştiriyoruz. Cloud Functions ile olay tabanlı işlemler, "
            "BigQuery ile zaman serisi analitik ve Terraform ile altyapı kod "
            "olarak yönetimi planlanıyor. Anomali tespiti için eşik tabanlı "
            "uyarı sistemi ve mobil bildirim entegrasyonu da kapsam dahilinde."
        ),
        "skills": [
            ("GCP", "DevOps"), ("Docker", "DevOps"),
            ("Kubernetes", "DevOps"), ("Linux", "DevOps"),
        ],
        "max_team": 3,
    },
]

for proj in PROJECTS:
    owner_user = profiles_by_email[proj["owner"]].user
    make_project(
        owner_user=owner_user,
        title=proj["title"],
        description=proj["description"],
        skill_names=proj["skills"],
        max_team=proj.get("max_team", 4),
    )

print(f"   ✓ {len(PROJECTS)} proje ilanı işlendi.")


# ─────────────────────────────────────────────────────────────────────────────
# 3. ÖZET RAPOR
# ─────────────────────────────────────────────────────────────────────────────
print("→ [3/3] Özet rapor...")

total_users     = User.objects.filter(email__endswith="@coforge.dev").count()
total_profiles  = DeveloperProfile.objects.count()
total_skills    = Skill.objects.count()
total_uskills   = UserSkill.objects.count()
total_projects  = ProjectPost.objects.filter(status=ProjectPost.Status.OPEN).count()
total_rskills   = ProjectRequiredSkill.objects.count()

print()
print("╔══════════════════════════════════════════╗")
print("║     Co-Forge — Seed tamamlandı ✅         ║")
print("╠══════════════════════════════════════════╣")
print(f"║  Kullanıcı (@coforge.dev)  : {total_users:<12}║")
print(f"║  DeveloperProfile          : {total_profiles:<12}║")
print(f"║  Skill (benzersiz)         : {total_skills:<12}║")
print(f"║  UserSkill                 : {total_uskills:<12}║")
print(f"║  ProjectPost (OPEN)        : {total_projects:<12}║")
print(f"║  ProjectRequiredSkill      : {total_rskills:<12}║")
print("╠══════════════════════════════════════════╣")
print("║  Tüm şifreler: CoForge2024!              ║")
print("╚══════════════════════════════════════════╝")
print()
print("TF-IDF eşleşme testini başlatmak için:")
print("  POST http://127.0.0.1:8000/api/auth/login/")
print("       { \"email\": \"ayse.kaya@coforge.dev\", \"password\": \"CoForge2024!\" }")
print("  GET  http://127.0.0.1:8000/api/me/match-suggestions/")
print("       Authorization: Bearer <token>")
