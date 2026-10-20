from alembic import context
from sqlalchemy import create_engine, pool, text
from webapp.config import database_url
from webapp.extensions import db
from webapp.models import Counter  # noqa: F401 - register model metadata

config = context.config
url = config.attributes.get("database_url") or database_url()

if context.is_offline_mode():
    context.configure(url=url, target_metadata=db.metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()
else:
    engine = create_engine(url, poolclass=pool.NullPool)
    with engine.connect() as connection:
        if connection.dialect.name == "postgresql":
            # Session lock serializes migration jobs for this application.
            connection.execute(text("SELECT pg_advisory_lock(76324519)"))
            connection.commit()
        context.configure(connection=connection, target_metadata=db.metadata)
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()
