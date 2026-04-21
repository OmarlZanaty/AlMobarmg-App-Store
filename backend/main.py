from fastapi import FastAPI

from backend.config import settings

app = FastAPI(title="Al Mobarmg Store API", version="0.1.0")


@app.get("/health")
async def health() -> dict[str, str | int]:
    return {
        "status": "ok",
        "service": "almobarmg-store-backend",
        "frontend_url": settings.frontend_url,
        "port": settings.port,
    }
