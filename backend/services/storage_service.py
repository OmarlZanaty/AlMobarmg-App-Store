from __future__ import annotations

import asyncio
import hashlib
import logging
from urllib.parse import urlparse

import boto3
from botocore.client import Config
from botocore.exceptions import BotoCoreError, ClientError

from backend.config import settings

logger = logging.getLogger(__name__)


class StorageService:
    """Async wrapper around boto3 for Cloudflare R2."""

    def __init__(self) -> None:
        self.bucket_name = settings.r2_bucket_name
        self.endpoint = (settings.r2_endpoint or "").rstrip("/")
        self._client = None

    def _get_client(self):
        if self._client is not None:
            return self._client

        if not self.endpoint:
            raise RuntimeError("R2_ENDPOINT is empty or missing")

        self._client = boto3.client(
            "s3",
            endpoint_url=self.endpoint,
            aws_access_key_id=settings.r2_access_key_id,
            aws_secret_access_key=settings.r2_secret_access_key,
            config=Config(signature_version="s3v4"),
            region_name="auto",
        )
        return self._client

    async def upload_file(self, file_bytes: bytes, filename: str, content_type: str, folder: str) -> str:
        key = f"{folder.strip('/')}/{filename}"
        client = self._get_client()
        try:
            await asyncio.to_thread(
                client.put_object,
                Bucket=self.bucket_name,
                Key=key,
                Body=file_bytes,
                ContentType=content_type,
            )
        except (BotoCoreError, ClientError) as exc:
            logger.exception("Failed to upload file to R2", extra={"key": key})
            raise RuntimeError("Failed to upload file") from exc

        return f"{self.endpoint}/{self.bucket_name}/{key}"

    async def delete_file(self, r2_url: str) -> bool:
        key = self._extract_key(r2_url)
        if not key:
            return False

        client = self._get_client()
        try:
            await asyncio.to_thread(client.delete_object, Bucket=self.bucket_name, Key=key)
            return True
        except (BotoCoreError, ClientError):
            logger.exception("Failed to delete file from R2", extra={"url": r2_url, "key": key})
            return False

    async def generate_signed_url(self, r2_url: str, expires_seconds: int = 3600) -> str:
        key = self._extract_key(r2_url)
        if not key:
            raise ValueError("Invalid R2 URL")

        client = self._get_client()
        try:
            return await asyncio.to_thread(
                client.generate_presigned_url,
                "get_object",
                Params={"Bucket": self.bucket_name, "Key": key},
                ExpiresIn=expires_seconds,
            )
        except (BotoCoreError, ClientError) as exc:
            logger.exception("Failed to generate signed URL", extra={"url": r2_url, "key": key})
            raise RuntimeError("Failed to generate signed URL") from exc

    @staticmethod
    def get_file_hash(file_bytes: bytes) -> str:
        return hashlib.sha256(file_bytes).hexdigest()

    def _extract_key(self, r2_url: str) -> str | None:
        if not r2_url:
            return None

        parsed = urlparse(r2_url)
        path = parsed.path.lstrip("/")
        bucket_prefix = f"{self.bucket_name}/"

        if path.startswith(bucket_prefix):
            return path[len(bucket_prefix) :]

        if parsed.netloc and parsed.netloc.split(".")[0] == self.bucket_name:
            return path

        return None


storage_service = StorageService()
