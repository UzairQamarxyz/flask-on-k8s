import pytest

from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_healthz(client):
    response = client.get("/healthz")
    assert response.status_code == 200
    assert b"Status: Ready" in response.data


def test_failcheck(client):
    response = client.get("/failcheck")
    assert response.status_code == 200
    assert b"Status: Alive" in response.data


def test_fact(client, monkeypatch):
    """Mock external API call and check HTML rendering."""

    class DummyResponse:
        def json(self):
            return {"text": "This is a mocked fact!"}

    def mock_get(*args, **kwargs):
        return DummyResponse()

    # Patch requests.get in app
    monkeypatch.setattr("app.requests.get", mock_get)

    response = client.get("/fact")
    assert response.status_code == 200
    assert b"<h1" in response.data
    assert b"This is a mocked fact!" in response.data
