from __future__ import annotations

from django.core.management.base import BaseCommand, CommandError

from core.services.nlp_service import milvus_hard_reset_and_reindex_entities


class Command(BaseCommand):
    help = (
        "Milvus project/user koleksiyonlarini drop eder, OPENAI_EMBEDDING_DIM ile yeniden yaratir "
        "(ilk upsert ile) ve tum ProjectPost + DeveloperProfile kayitlarini yeniden indeksler."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--projects-limit",
            type=int,
            default=None,
            help="Islenecek maksimum ilan sayisi (varsayilan: tum ilanlar).",
        )
        parser.add_argument(
            "--users-limit",
            type=int,
            default=None,
            help="Islenecek maksimum gelistirici profili (varsayilan: tum profiller).",
        )

    def handle(self, *args, **options):
        pl = options.get("projects_limit")
        ul = options.get("users_limit")
        result = milvus_hard_reset_and_reindex_entities(projects_limit=pl, users_limit=ul)
        if result.get("ok"):
            self.stdout.write(self.style.SUCCESS(result.get("message", str(result))))
            self.stdout.write(str(result))
        else:
            self.stderr.write(self.style.ERROR(str(result)))
            raise CommandError(result.get("error") or result.get("phase") or "Milvus hard reset basarisiz")
