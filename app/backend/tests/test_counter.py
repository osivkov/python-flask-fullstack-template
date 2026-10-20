from unittest.mock import patch

from sqlalchemy.exc import OperationalError
from webapp.extensions import db


def test_liveness_does_not_query_database(client):
    with patch.object(db.session, "execute", side_effect=AssertionError("DB used")):
        response = client.get("/healthz")
    assert response.status_code == 200


def test_readiness_reports_database_failure(client):
    with patch.object(
        db.session, "execute", side_effect=OperationalError("private error", None, None)
    ):
        response = client.get("/readyz")
    assert response.status_code == 503
    assert "private error" not in response.get_data(as_text=True)


def test_increment_is_persisted(client):
    response = client.post("/api/increment")
    assert response.status_code == 200
    assert response.get_json() == {"counter": 1, "version": "test"}
    assert client.get("/api/status").get_json() == {"counter": 1, "version": "test"}


def test_cross_origin_post_does_not_change_counter(client):
    response = client.post(
        "/api/increment", headers={"Origin": "https://elsewhere.invalid"}
    )
    assert response.status_code == 403
    assert client.get("/api/status").get_json()["counter"] == 0


def test_trusted_proxy_preserves_https_origin(client):
    response = client.post(
        "/api/increment",
        headers={
            "Host": "app.example.com",
            "X-Forwarded-Proto": "https",
            "Origin": "https://app.example.com",
        },
    )
    assert response.status_code == 200


def test_backend_does_not_serve_frontend(client):
    assert client.get("/").status_code == 404
    assert client.get("/static/styles.css").status_code == 404
