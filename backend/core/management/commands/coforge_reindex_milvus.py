from __future__ import annotations

from django.core.management.base import BaseCommand, CommandError

from core.services.nlp_service import milvus_hard_reset_and_reindex_entities, reindex_all_milvus_entities


class Command(BaseCommand):
    help = "Acik ilanlar + profiller icin Milvus yeniden yazar. --hard-reset: koleksiyonlari drop + tum kayitlar."

    def add_arguments(self, parser):
        parser.add_argument(
            "--hard-reset",
            action="store_true",
            help="Koleksiyonlari sil, yeniden olustur ve TUM ilan/profilleri indeksle (reindex_milvus ile ayni agir is).",
        )
        parser.add_argument(
            "--projects-limit",
            type=int,
            default=None,
            help="Islenecek maksimum ilan sayisi (varsayilan: sinirsiz).",
        )
        parser.add_argument(
            "--users-limit",
            type=int,
            default=None,
            help="Islenecek maksimum kullanici profili sayisi (varsayilan: sinirsiz).",
        )

    def handle(self, *args, **options):
        pl = options.get("projects_limit")
        ul = options.get("users_limit")
        if options.get("hard_reset"):
            result = milvus_hard_reset_and_reindex_entities(projects_limit=pl, users_limit=ul)
        else:
            result = reindex_all_milvus_entities(projects_limit=pl, users_limit=ul)
        if result.get("ok"):
            self.stdout.write(self.style.SUCCESS(result.get("message", str(result))))
            self.stdout.write(str(result))
        else:
            self.stderr.write(self.style.ERROR(str(result)))
            raise CommandError(result.get("error") or result.get("phase") or "Milvus reindex basarisiz")
