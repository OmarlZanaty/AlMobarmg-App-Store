from celery import Celery

from backend.config import settings

celery_app = Celery(
    "almobarmg_worker",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=["backend.workers.security_scan", "backend.workers.fix_rejection"],
)
