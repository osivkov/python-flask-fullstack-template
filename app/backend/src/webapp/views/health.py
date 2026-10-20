from flask import Blueprint, current_app, jsonify
from sqlalchemy import text

from webapp.extensions import db

health = Blueprint("health", __name__)


@health.get("/healthz")
def liveness():
    return jsonify(status="alive", version=current_app.config["APP_VERSION"])


@health.get("/readyz")
def readiness():
    db.session.execute(text("SELECT 1"))
    return jsonify(status="ready", version=current_app.config["APP_VERSION"])
