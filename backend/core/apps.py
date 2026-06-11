from django.apps import AppConfig


class CoreConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'core'

    def ready(self) -> None:
        # Milvus senkron: profil / ilan / yetenek degisimi
        from . import signals  # noqa: F401
