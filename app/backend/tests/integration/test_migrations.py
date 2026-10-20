from alembic import command
from alembic.config import Config
from sqlalchemy import URL, create_engine, text


def migration_config(tmp_path):
    config = Config("alembic.ini")
    config.attributes["database_url"] = URL.create(
        "sqlite", database=str(tmp_path / "test.db")
    )
    return config


def test_upgrade_creates_and_seeds_database(tmp_path):
    config = migration_config(tmp_path)
    command.upgrade(config, "head")
    command.upgrade(config, "head")
    with create_engine(config.attributes["database_url"]).connect() as connection:
        assert connection.execute(text("SELECT value FROM counter")).scalar_one() == 0
        assert (
            connection.execute(
                text("SELECT version_num FROM alembic_version")
            ).scalar_one()
            == "0001_counter"
        )


def test_downgrade_and_upgrade_on_disposable_database(tmp_path):
    config = migration_config(tmp_path)
    engine = create_engine(config.attributes["database_url"])
    command.upgrade(config, "head")
    command.check(config)
    command.downgrade(config, "base")
    command.upgrade(config, "head")
    with engine.connect() as connection:
        assert connection.execute(text("SELECT value FROM counter")).scalar_one() == 0
    engine.dispose()
