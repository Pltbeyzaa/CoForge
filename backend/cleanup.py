"""
Co-Forge — Bozuk seed verisi temizleme scripti.

Kullanim:
    cd backend
    python cleanup.py

Ne yapar:
  1. Tum ProjectPost kayitlarini siler (cascade ile RequiredSkill/Match da gider).
  2. Seed ile eklenmis @coforge.dev uzantili User + DeveloperProfile kayitlarini siler.
  3. Ana hesap (beyzapolat019@gmail.com veya baska @coforge.dev disindaki hesaplar) korunur.
"""

import os
import sys
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "coforge_backend.settings")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
django.setup()

from django.contrib.auth import get_user_model
from core.models import ProjectPost

User = get_user_model()

# ---------------------------------------------------------------------------
# 1. Tum proje ilanlarini sil
# ---------------------------------------------------------------------------
post_count, post_detail = ProjectPost.objects.all().delete()
print(f"[1/2] ProjectPost ve bagli kayitlar silindi: {post_detail}")

# ---------------------------------------------------------------------------
# 2. Seed kullanicilari sil (@coforge.dev — ana hesap KORUNUR)
# ---------------------------------------------------------------------------
seed_users = User.objects.filter(email__endswith="@coforge.dev")
user_count = seed_users.count()
_, user_detail = seed_users.delete()   # CASCADE: DeveloperProfile, UserSkill, vb.
print(f"[2/2] Seed kullanici + bagli kayitlar silindi: {user_detail}")

# ---------------------------------------------------------------------------
# Ozet
# ---------------------------------------------------------------------------
remaining_users    = User.objects.count()
remaining_projects = ProjectPost.objects.count()

print()
print("=" * 48)
print("  Temizlik tamamlandi!")
print(f"  Silinen @coforge.dev kullanici : {user_count}")
print(f"  Silinen ProjectPost            : {post_count}")
print(f"  Kalan kullanici (korunan)      : {remaining_users}")
print(f"  Kalan ProjectPost              : {remaining_projects}")
print("=" * 48)
print()
print("Simdi tekrar doldurmak icin:")
print("  python seed_db.py")
