#!/usr/bin/env python3
import asyncio
import sys
import uuid

from sqlalchemy import select

from backend.config import settings
from backend.database import AsyncSessionLocal
from backend.models.enums import UserRole
from backend.models.user import User
from backend.services.auth_service import hash_password


async def create_admin(email: str, name: str, password: str) -> uuid.UUID:
    _ = settings

    async with AsyncSessionLocal() as db:
        existing_user = await db.scalar(select(User).where(User.email == email.lower()))
        if existing_user is not None:
            raise ValueError(f"User with email {email} already exists (id={existing_user.id})")

        admin_user = User(
            email=email.lower(),
            name=name,
            password_hash=hash_password(password),
            role=UserRole.admin,
            is_email_verified=True,
        )
        db.add(admin_user)
        await db.commit()
        await db.refresh(admin_user)
        return admin_user.id


def main() -> int:
    if len(sys.argv) != 4:
        print('Usage: python scripts/create_admin.py admin@example.com "Admin Name" "password123"')
        return 1

    email = sys.argv[1].strip()
    name = sys.argv[2].strip()
    password = sys.argv[3]

    if not email or not name or not password:
        print("Error: email, name, and password must all be provided.")
        return 1

    try:
        user_id = asyncio.run(create_admin(email=email, name=name, password=password))
    except ValueError as exc:
        print(f"Error: {exc}")
        return 1

    print(f"✅ Admin user created successfully with ID: {user_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
