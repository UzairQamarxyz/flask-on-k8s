import os
from typing import Any, Dict

import requests
from flask import Flask, Response

app: Flask = Flask(__name__)

API_URL: str = "https://uselessfacts.jsph.pl/api/v2/facts/random"
TITLE: str = os.getenv("APP_TITLE", "Random Facts API")


def get_language() -> str:
    return os.getenv("APP_LANGUAGE", "en")


@app.route("/fact")
def get_fact() -> Response:
    """Fetch a random useless fact and render as HTML."""
    try:
        language: str = get_language()
        response: requests.Response = requests.get(API_URL, params={"language": language}, timeout=5)
        data: Dict[str, Any] = response.json()
        fact: str = data.get("text", "No fact available")

        html = f"""
        <!DOCTYPE html>
        <html>
          <head>
            <title>{TITLE}</title>
          </head>
          <body>
            <h1>{TITLE}</h1>
            <p><strong>Language:</strong> {language}</p>
            <p><em>{fact}</em></p>
          </body>
        </html>
        """
        return Response(html, mimetype="text/html")

    except Exception as e:
        return Response(f"<h3>Error: {str(e)}</h3>", mimetype="text/html", status=500)


@app.route("/healthz")
def healthz() -> Response:
    return Response("<h3>Status: Ready</h3>", mimetype="text/html")


@app.route("/failcheck")
def failcheck() -> Response:
    return Response("<h3>Status: Alive</h3>", mimetype="text/html")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
