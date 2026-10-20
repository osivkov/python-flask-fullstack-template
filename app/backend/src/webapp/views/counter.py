from flask import Blueprint, current_app, jsonify, request
from sqlalchemy import select, update

from webapp.extensions import db
from webapp.models import Counter

counter = Blueprint("counter", __name__)


def counter_value():
    return db.session.execute(select(Counter.value).where(Counter.id == 1)).scalar_one()


@counter.get("/api/status")
def status():
    return jsonify(version=current_app.config["APP_VERSION"], counter=counter_value())


@counter.post("/api/increment")
def increment():
    origin = request.headers.get("Origin")
    if origin and origin != request.host_url.rstrip("/"):
        return jsonify(error="Origin rejected"), 403

    # Update in the database to avoid lost increments across workers.
    db.session.execute(
        update(Counter).where(Counter.id == 1).values(value=Counter.value + 1)
    )
    db.session.commit()
    return jsonify(version=current_app.config["APP_VERSION"], counter=counter_value())
