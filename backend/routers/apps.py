from __future__ import annotations

import logging
import uuid
from typing import Annotated, Any
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import and_, desc, func, select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from backend.database import get_db
from backend.middleware.auth import get_current_developer, get_optional_user
from backend.models.app import App
from backend.models.enums import AppStatus, InstallSource, Platform, SubscriptionPlan
from backend.models.install import Install
from backend.models.security_report import SecurityReport
from backend.models.user import User
from backend.services.auth_service import redis_client
from backend.services.storage_service import storage_service
from backend.workers.security_scan import scan_app

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["apps"])

PLAN_MAX_MB = {
    SubscriptionPlan.free: 100,
    SubscriptionPlan.pro: 1024,
    SubscriptionPlan.studio: 4096,
}

PLATFORM_FILE_RULES = {
    "android_file": {
        "platform": Platform.android,
        "ext": {".apk", ".aab"},
        "mime": {"application/vnd.android.package-archive", "application/octet-stream", "application/x-authorware-bin"},
    },
    "windows_file": {
        "platform": Platform.windows,
        "ext": {".exe", ".msix"},
        "mime": {"application/x-msdownload", "application/octet-stream", "application/vnd.ms-appx"},
    },
    "mac_file": {
        "platform": Platform.mac,
        "ext": {".dmg"},
        "mime": {"application/x-apple-diskimage", "application/octet-stream"},
    },
    "linux_deb_file": {
        "platform": Platform.linux,
        "ext": {".deb"},
        "mime": {"application/vnd.debian.binary-package", "application/octet-stream"},
    },
    "linux_appimage_file": {
        "platform": Platform.linux,
        "ext": {".appimage"},
        "mime": {"application/octet-stream", "application/x-iso9660-appimage"},
    },
    "linux_rpm_file": {
        "platform": Platform.linux,
        "ext": {".rpm"},
        "mime": {"application/x-rpm", "application/octet-stream"},
    },
}

IMAGE_MIME_TYPES = {"image/png", "image/jpeg", "image/webp", "image/gif"}


class AppCreateResponse(BaseModel):
    app_id: str
    status: str
    message: str
    estimated_scan_minutes: int


class AppListItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    short_description: str
    category: str
    icon_url: str
    supported_platforms: list[str]
    total_installs: int
    security_score: int | None
    status: str
    risk_badge: str


class AppDetailResponse(BaseModel):
    app: dict[str, Any]
    latest_security_report: dict[str, Any] | None
    developer: dict[str, Any]
    install_counts: dict[str, int]
    install_urls: dict[str, str]


class InstallRequest(BaseModel):
    platform: Platform


def _file_ext(name: str) -> str:
    if "." not in name:
        return ""
    return f".{name.rsplit('.', 1)[-1].lower()}"


async def _read_and_validate_upload(file: UploadFile, *, max_bytes: int, allowed_ext: set[str], allowed_mime: set[str], label: str) -> bytes:
    if not file.filename:
        raise HTTPException(status_code=400, detail=f"{label} filename missing")

    ext = _file_ext(file.filename)
    if ext not in {e.lower() for e in allowed_ext}:
        raise HTTPException(status_code=400, detail=f"Invalid {label} extension")

    content_type = (file.content_type or "").lower()
    if content_type not in {m.lower() for m in allowed_mime}:
        raise HTTPException(status_code=400, detail=f"Invalid {label} content type")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail=f"{label} cannot be empty")
    if len(content) > max_bytes:
        raise HTTPException(status_code=400, detail=f"{label} exceeds size limit")
    return content


def _validate_https_url(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.netloc:
        raise HTTPException(status_code=400, detail="ios_pwa_url must be a valid HTTPS URL")
    return url


@router.post("/developer/apps", response_model=AppCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_app(
    name: Annotated[str, Form(min_length=1)],
    description: Annotated[str, Form(min_length=50)],
    short_description: Annotated[str, Form(min_length=1, max_length=200)],
    category: Annotated[str, Form(min_length=1)],
    version: Annotated[str, Form(min_length=1, max_length=64)],
    android_file: UploadFile | None = File(default=None),
    ios_pwa_url: str | None = Form(default=None),
    windows_file: UploadFile | None = File(default=None),
    mac_file: UploadFile | None = File(default=None),
    linux_deb_file: UploadFile | None = File(default=None),
    linux_appimage_file: UploadFile | None = File(default=None),
    linux_rpm_file: UploadFile | None = File(default=None),
    icon: UploadFile = File(...),
    screenshots: list[UploadFile] = File(...),
    current_developer: User = Depends(get_current_developer),
    db: AsyncSession = Depends(get_db),
) -> AppCreateResponse:
    provided_files = {
        "android_file": android_file,
        "windows_file": windows_file,
        "mac_file": mac_file,
        "linux_deb_file": linux_deb_file,
        "linux_appimage_file": linux_appimage_file,
        "linux_rpm_file": linux_rpm_file,
    }

    if not any(v is not None for v in provided_files.values()) and not ios_pwa_url:
        raise HTTPException(status_code=400, detail="At least one platform file or iOS PWA URL is required")

    if ios_pwa_url:
        ios_pwa_url = _validate_https_url(ios_pwa_url.strip())

    if not (2 <= len(screenshots) <= 8):
        raise HTTPException(status_code=400, detail="screenshots must include 2 to 8 images")

    max_mb = PLAN_MAX_MB.get(current_developer.subscription_plan, 100)
    max_file_bytes = max_mb * 1024 * 1024

    icon_bytes = await _read_and_validate_upload(
        icon,
        max_bytes=2 * 1024 * 1024,
        allowed_ext={".png", ".jpg", ".jpeg", ".webp", ".gif"},
        allowed_mime=IMAGE_MIME_TYPES,
        label="icon",
    )

    screenshot_payloads: list[tuple[UploadFile, bytes]] = []
    for i, shot in enumerate(screenshots, start=1):
        payload = await _read_and_validate_upload(
            shot,
            max_bytes=5 * 1024 * 1024,
            allowed_ext={".png", ".jpg", ".jpeg", ".webp", ".gif"},
            allowed_mime=IMAGE_MIME_TYPES,
            label=f"screenshot #{i}",
        )
        screenshot_payloads.append((shot, payload))

    validated_platform_files: dict[str, tuple[UploadFile, bytes]] = {}
    for key, upload in provided_files.items():
        if upload is None:
            continue
        rules = PLATFORM_FILE_RULES[key]
        file_bytes = await _read_and_validate_upload(
            upload,
            max_bytes=max_file_bytes,
            allowed_ext=rules["ext"],
            allowed_mime=rules["mime"],
            label=key,
        )
        validated_platform_files[key] = (upload, file_bytes)

    app_id = uuid.uuid4()
    package_id = f"com.almobarmg.{app_id.hex[:12]}"

    app = App(
        id=app_id,
        developer_id=current_developer.id,
        name=name.strip(),
        package_id=package_id,
        description=description.strip(),
        category=category.strip(),
        short_description=short_description.strip(),
        icon_url="",
        screenshots=[],
        version=version.strip(),
        status=AppStatus.pending,
        supported_platforms=[],
        ios_pwa_url=ios_pwa_url,
        file_sizes={},
    )
    db.add(app)

    file_sizes: dict[str, float] = {}
    supported_platforms: set[str] = set([Platform.ios.value] if ios_pwa_url else [])

    try:
        if validated_platform_files:
            for key, (upload, file_bytes) in validated_platform_files.items():
                filename = f"{key}_{uuid.uuid4().hex}{_file_ext(upload.filename or '')}"
                url = await storage_service.upload_file(
                    file_bytes=file_bytes,
                    filename=filename,
                    content_type=(upload.content_type or "application/octet-stream"),
                    folder=f"apps/{app_id}/platform",
                )
                file_sizes[key] = round(len(file_bytes) / (1024 * 1024), 3)

                if key == "android_file":
                    app.android_file_url = url
                elif key == "windows_file":
                    app.windows_file_url = url
                elif key == "mac_file":
                    app.mac_file_url = url
                elif key == "linux_deb_file":
                    app.linux_deb_url = url
                elif key == "linux_appimage_file":
                    app.linux_appimage_url = url
                elif key == "linux_rpm_file":
                    app.linux_rpm_url = url

                supported_platforms.add(PLATFORM_FILE_RULES[key]["platform"].value)

        app.icon_url = await storage_service.upload_file(
            file_bytes=icon_bytes,
            filename=f"icon_{uuid.uuid4().hex}{_file_ext(icon.filename or '')}",
            content_type=(icon.content_type or "application/octet-stream"),
            folder=f"apps/{app_id}/icon",
        )

        screenshot_urls: list[str] = []
        for shot, shot_bytes in screenshot_payloads:
            screenshot_urls.append(
                await storage_service.upload_file(
                    file_bytes=shot_bytes,
                    filename=f"screenshot_{uuid.uuid4().hex}{_file_ext(shot.filename or '')}",
                    content_type=(shot.content_type or "application/octet-stream"),
                    folder=f"apps/{app_id}/screenshots",
                )
            )

        app.screenshots = screenshot_urls
        app.file_sizes = file_sizes
        app.supported_platforms = sorted(supported_platforms)
        app.status = AppStatus.scanning

        await db.commit()
        await db.refresh(app)

        scan_app.delay(str(app.id))

    except HTTPException:
        await db.rollback()
        raise
    except Exception as exc:
        await db.rollback()
        logger.exception("App creation failed", extra={"app_id": str(app_id), "developer_id": str(current_developer.id)})
        raise HTTPException(status_code=500, detail="Failed to submit app") from exc

    return AppCreateResponse(
        app_id=str(app.id),
        status=AppStatus.scanning.value,
        message="App submitted. Security scan started.",
        estimated_scan_minutes=5,
    )


@router.get("/apps", response_model=dict[str, Any])
async def list_apps(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    category: str | None = Query(default=None),
    platform: Platform | None = Query(default=None),
    min_security_score: int | None = Query(default=None, ge=0, le=100),
    sort: str = Query(default="newest", pattern="^(newest|highest_score|most_installs)$"),
    q: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
) -> dict[str, Any]:
    filters = [App.status == AppStatus.approved]
    if category:
        filters.append(App.category == category)
    if platform:
        filters.append(App.supported_platforms.contains([platform.value]))
    if min_security_score is not None:
        filters.append(App.security_score >= min_security_score)
    if q:
        filters.append(
            text(
                "to_tsvector('simple', coalesce(apps.name,'') || ' ' || coalesce(apps.description,'') || ' ' || coalesce(apps.category,'')) "
                "@@ plainto_tsquery('simple', :q)"
            ).bindparams(q=q)
        )

    stmt = select(App).where(and_(*filters))
    if sort == "highest_score":
        stmt = stmt.order_by(desc(App.security_score), desc(App.created_at))
    elif sort == "most_installs":
        stmt = stmt.order_by(desc(App.total_installs), desc(App.created_at))
    else:
        stmt = stmt.order_by(desc(App.created_at))

    total_stmt = select(func.count(App.id)).where(and_(*filters))
    total = (await db.execute(total_stmt)).scalar_one()

    stmt = stmt.offset((page - 1) * limit).limit(limit)
    rows = (await db.execute(stmt)).scalars().all()

    items = [
        AppListItem(
            id=str(app.id),
            name=app.name,
            short_description=app.short_description,
            category=app.category,
            icon_url=app.icon_url,
            supported_platforms=app.supported_platforms,
            total_installs=app.total_installs,
            security_score=app.security_score,
            status=app.status.value,
            risk_badge=(
                "safe"
                if (app.security_score or 0) >= 85
                else "low"
                if (app.security_score or 0) >= 65
                else "medium"
                if (app.security_score or 0) >= 45
                else "high"
                if (app.security_score or 0) >= 25
                else "critical"
            ),
        ).model_dump()
        for app in rows
    ]

    return {"page": page, "limit": limit, "total": total, "items": items}


@router.get("/apps/{app_id}", response_model=AppDetailResponse)
async def get_app(app_id: str, db: AsyncSession = Depends(get_db)) -> AppDetailResponse:
    try:
        app_uuid = uuid.UUID(app_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid app_id") from exc

    app = (
        await db.execute(
            select(App)
            .options(selectinload(App.security_reports), selectinload(App.developer))
            .where(App.id == app_uuid)
        )
    ).scalar_one_or_none()
    if app is None:
        raise HTTPException(status_code=404, detail="App not found")

    report: SecurityReport | None = None
    if app.security_reports:
        report = max(app.security_reports, key=lambda item: item.scanned_at)

    developer = app.developer

    platform_counts_stmt = select(Install.platform, func.count(Install.id)).where(Install.app_id == app.id).group_by(Install.platform)
    counts_rows = (await db.execute(platform_counts_stmt)).all()
    install_counts = {row[0].value: row[1] for row in counts_rows}

    install_urls: dict[str, str] = {}
    for key, raw_url in {
        "android": app.android_file_url,
        "ios": app.ios_pwa_url,
        "windows": app.windows_file_url,
        "mac": app.mac_file_url,
        "linux_deb": app.linux_deb_url,
        "linux_appimage": app.linux_appimage_url,
        "linux_rpm": app.linux_rpm_url,
    }.items():
        if not raw_url:
            continue
        if key == "ios":
            install_urls[key] = raw_url
        else:
            install_urls[key] = await storage_service.generate_signed_url(raw_url)

    return AppDetailResponse(
        app={
            "id": str(app.id),
            "name": app.name,
            "description": app.description,
            "short_description": app.short_description,
            "category": app.category,
            "status": app.status.value,
            "security_score": app.security_score,
            "supported_platforms": app.supported_platforms,
            "icon_url": app.icon_url,
            "screenshots": app.screenshots,
            "total_installs": app.total_installs,
            "created_at": app.created_at.isoformat() if app.created_at else None,
            "published_at": app.published_at.isoformat() if app.published_at else None,
        },
        latest_security_report=(
            {
                "id": str(report.id),
                "score": report.score,
                "risk_level": report.risk_level.value,
                "ai_summary": report.ai_summary,
                "dangerous_permissions": report.dangerous_permissions,
                "scanned_at": report.scanned_at.isoformat() if report.scanned_at else None,
            }
            if report
            else None
        ),
        developer={
            "id": str(developer.id),
            "email": developer.email,
            "reputation_score": developer.reputation_score,
        },
        install_counts=install_counts,
        install_urls=install_urls,
    )


@router.post("/apps/{app_id}/install", response_model=dict[str, str])
async def install_app(
    app_id: str,
    payload: InstallRequest,
    request: Request,
    optional_user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
) -> dict[str, str]:
    ip_address = request.client.host if request.client else "unknown"
    rate_key = f"install_rate:{ip_address}:{app_id}"
    count = await redis_client.incr(rate_key)
    if count == 1:
        await redis_client.expire(rate_key, 3600)
    if count > 5:
        raise HTTPException(status_code=429, detail="Too many install requests")

    try:
        app_uuid = uuid.UUID(app_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid app_id") from exc

    app = (await db.execute(select(App).where(App.id == app_uuid))).scalar_one_or_none()
    if app is None:
        raise HTTPException(status_code=404, detail="App not found")

    if app.status != AppStatus.approved:
        raise HTTPException(status_code=403, detail="App is not available for installation")

    if payload.platform == Platform.ios:
        if not app.ios_pwa_url:
            raise HTTPException(status_code=400, detail="iOS PWA URL is not available for this app")
        target_url = app.ios_pwa_url
    elif payload.platform == Platform.android:
        if not app.android_file_url:
            raise HTTPException(status_code=400, detail="Android package not available")
        target_url = await storage_service.generate_signed_url(app.android_file_url)
    elif payload.platform == Platform.windows:
        if not app.windows_file_url:
            raise HTTPException(status_code=400, detail="Windows installer not available")
        target_url = await storage_service.generate_signed_url(app.windows_file_url)
    elif payload.platform == Platform.mac:
        if not app.mac_file_url:
            raise HTTPException(status_code=400, detail="Mac installer not available")
        target_url = await storage_service.generate_signed_url(app.mac_file_url)
    elif payload.platform == Platform.linux:
        linux_url = app.linux_deb_url or app.linux_appimage_url or app.linux_rpm_url
        if not linux_url:
            raise HTTPException(status_code=400, detail="Linux package not available")
        target_url = await storage_service.generate_signed_url(linux_url)
    else:
        raise HTTPException(status_code=400, detail="Unsupported platform")

    install = Install(
        app_id=app.id,
        user_id=optional_user.id if optional_user else None,
        platform=payload.platform,
        install_source=InstallSource.store,
        country_code=None,
    )
    db.add(install)
    app.total_installs += 1
    await db.commit()

    return {"platform": payload.platform.value, "install_url": target_url}


@router.get("/developer/apps", response_model=list[dict[str, Any]])
async def list_developer_apps(
    current_developer: User = Depends(get_current_developer),
    db: AsyncSession = Depends(get_db),
) -> list[dict[str, Any]]:
    rows = (
        await db.execute(
            select(App)
            .where(App.developer_id == current_developer.id)
            .order_by(desc(App.created_at))
        )
    ).scalars().all()

    return [
        {
            "id": str(app.id),
            "name": app.name,
            "status": app.status.value,
            "security_score": app.security_score,
            "supported_platforms": app.supported_platforms,
            "file_sizes": app.file_sizes,
            "created_at": app.created_at.isoformat() if app.created_at else None,
            "published_at": app.published_at.isoformat() if app.published_at else None,
            "total_installs": app.total_installs,
        }
        for app in rows
    ]
