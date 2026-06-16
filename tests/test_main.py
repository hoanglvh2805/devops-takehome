import httpx
import pytest
from fastapi.testclient import TestClient

from main import app


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def test_healthz(client):
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_readyz(client):
    r = client.get("/readyz")
    assert r.status_code == 200


def test_metrics(client):
    r = client.get("/metrics")
    assert r.status_code == 200
    assert "quote_api_requests_total" in r.text


def test_quote(client):
    r = client.get("/api/quote")
    assert r.status_code == 200
    body = r.json()
    assert "text" in body
    assert "author" in body
