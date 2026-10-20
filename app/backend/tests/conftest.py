import pytest
from webapp import create_app
from webapp.extensions import db
from webapp.models import Counter


@pytest.fixture
def app():
    application = create_app(
        {"TESTING": True, "SQLALCHEMY_DATABASE_URI": "sqlite://", "APP_VERSION": "test"}
    )
    with application.app_context():
        db.create_all()
        db.session.add(Counter(id=1, value=0))
        db.session.commit()
        yield application
        db.session.remove()
        db.drop_all()
        db.engine.dispose()


@pytest.fixture
def client(app):
    return app.test_client()
