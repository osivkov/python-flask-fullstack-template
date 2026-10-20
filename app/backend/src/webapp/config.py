import os
from pathlib import Path

from sqlalchemy import URL


def database_url():
    password = (
        Path(os.getenv("DB_PASSWORD_FILE", "/run/secrets/db_app_password"))
        .read_text(encoding="utf-8")
        .strip()
    )
    return URL.create(
        "postgresql+psycopg",
        username=os.getenv("DB_USER", "app"),
        password=password,
        host=os.getenv("DB_HOST", "postgres"),
        port=int(os.getenv("DB_PORT", "5432")),
        database=os.getenv("DB_NAME", "app"),
        query={
            "connect_timeout": "3",
            "options": "-c statement_timeout=5000 -c lock_timeout=3000",
        },
    )
