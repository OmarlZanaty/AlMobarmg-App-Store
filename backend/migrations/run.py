import asyncio
from pathlib import Path

import asyncpg

from backend.config import settings


MIGRATIONS_DIR = Path(__file__).resolve().parent


CREATE_MIGRATIONS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS schema_migrations (
    filename TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
"""


async def run_migrations() -> None:
    database_url = settings.database_url
    if database_url.startswith("postgresql+asyncpg://"):
        database_url = database_url.replace("postgresql+asyncpg://", "postgresql://", 1)
    elif database_url.startswith("postgres+asyncpg://"):
        database_url = database_url.replace("postgres+asyncpg://", "postgres://", 1)

    connection = await asyncpg.connect(database_url)
    try:
        await connection.execute(CREATE_MIGRATIONS_TABLE_SQL)

        sql_files = sorted(path for path in MIGRATIONS_DIR.glob("*.sql") if path.is_file())
        for sql_file in sql_files:
            already_applied = await connection.fetchval(
                "SELECT 1 FROM schema_migrations WHERE filename = $1",
                sql_file.name,
            )
            if already_applied:
                print(f"Skipping migration (already applied): {sql_file.name}")
                continue

            sql_content = sql_file.read_text(encoding="utf-8").strip()
            if not sql_content:
                print(f"Skipping empty migration: {sql_file.name}")
                continue

            print(f"Running migration: {sql_file.name}")
            async with connection.transaction():
                await connection.execute(sql_content)
                await connection.execute(
                    "INSERT INTO schema_migrations (filename) VALUES ($1)",
                    sql_file.name,
                )

        print("Migrations completed successfully.")
    finally:
        await connection.close()


if __name__ == "__main__":
    asyncio.run(run_migrations())
