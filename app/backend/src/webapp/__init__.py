import os

from flask import Flask, jsonify
from sqlalchemy.exc import SQLAlchemyError
from werkzeug.middleware.proxy_fix import ProxyFix

from webapp.config import database_url
from webapp.extensions import db


def create_app(config=None):
    app = Flask(__name__, static_folder=None)
    app.config.from_mapping(
        APP_VERSION=os.getenv("APP_VERSION", "dev"),
        SQLALCHEMY_TRACK_MODIFICATIONS=False,
        SQLALCHEMY_ENGINE_OPTIONS={"pool_pre_ping": True},
    )
    if config:
        app.config.update(config)
    if "SQLALCHEMY_DATABASE_URI" not in app.config:
        app.config["SQLALCHEMY_DATABASE_URI"] = database_url()

    # The backend is private and accepts traffic through one trusted proxy.
    app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)
    db.init_app(app)

    from webapp.views.counter import counter
    from webapp.views.health import health

    app.register_blueprint(health)
    app.register_blueprint(counter)

    @app.errorhandler(SQLAlchemyError)
    def database_error(error):
        db.session.rollback()
        app.logger.error("Database request failed: %s", type(error).__name__)
        return jsonify(error="Database unavailable"), 503

    return app
