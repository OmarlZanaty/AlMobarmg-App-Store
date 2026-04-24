import os
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=("/home/ubuntu/.env", ".env"),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    database_url: str = Field(alias="DATABASE_URL")
    redis_url: str = Field(alias="REDIS_URL")

    jwt_secret: str = Field(alias="JWT_SECRET")
    jwt_refresh_secret: str = Field(alias="JWT_REFRESH_SECRET")
    jwt_expires_in: str = Field(alias="JWT_EXPIRES_IN")
    jwt_refresh_expires_in: str = Field(alias="JWT_REFRESH_EXPIRES_IN")

    mobsf_url: str = Field(alias="MOBSF_URL")
    mobsf_api_key: str = Field(alias="MOBSF_API_KEY")
    virustotal_api_key: str = Field(alias="VIRUSTOTAL_API_KEY")
    anthropic_api_key: str = Field(default="", alias="ANTHROPIC_API_KEY")

    resend_api_key: str = Field(alias="RESEND_API_KEY")
    email_from: str = Field(alias="EMAIL_FROM")

    r2_account_id: str = Field(default="", alias="R2_ACCOUNT_ID")
    r2_access_key_id: str = Field(default="", alias="R2_ACCESS_KEY_ID")
    r2_secret_access_key: str = Field(default="", alias="R2_SECRET_ACCESS_KEY")
    r2_bucket_name: str = Field(alias="R2_BUCKET_NAME")
    r2_endpoint: str = Field(default="", alias="R2_ENDPOINT")

    stripe_secret_key: str = Field(default="", alias="STRIPE_SECRET_KEY")
    stripe_webhook_secret: str = Field(default="", alias="STRIPE_WEBHOOK_SECRET")
    stripe_pro_price_id: str = Field(default="price_pro_monthly", alias="STRIPE_PRO_PRICE_ID")
    stripe_studio_price_id: str = Field(default="price_studio_monthly", alias="STRIPE_STUDIO_PRICE_ID")

    port: int = Field(default=8000, alias="PORT")
    frontend_url: str = Field(alias="FRONTEND_URL")

    max_file_size_mb: int = Field(default=500, alias="MAX_FILE_SIZE_MB")
    free_plan_max_mb: int = Field(default=100, alias="FREE_PLAN_MAX_MB")


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    if os.getenv("TEST_ENV") == "1":
        test_defaults = {
            "DATABASE_URL": "sqlite+aiosqlite:///./test.db",
            "REDIS_URL": "redis://localhost:6379/0",
            "JWT_SECRET": "test-jwt-secret",
            "JWT_REFRESH_SECRET": "test-jwt-refresh-secret",
            "JWT_EXPIRES_IN": "15m",
            "JWT_REFRESH_EXPIRES_IN": "7d",
            "MOBSF_URL": "http://localhost:8000",
            "MOBSF_API_KEY": "test-mobsf-key",
            "VIRUSTOTAL_API_KEY": "test-vt-key",
            "RESEND_API_KEY": "test-resend-key",
            "EMAIL_FROM": "noreply@almobarmg.test",
            "R2_BUCKET_NAME": "almobarmg-test-bucket",
            "FRONTEND_URL": "http://localhost:3000",
        }
        for key, value in test_defaults.items():
            os.environ.setdefault(key, value)
    return Settings()


settings = get_settings()
