import json
import logging
import os
from typing import Any, Dict

import requests
from flask import Flask, Response, request

app: Flask = Flask(__name__)

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)
logger = logging.getLogger(__name__)

API_URL: str = "https://uselessfacts.jsph.pl/api/v2/facts/random"
TITLE: str = os.getenv("APP_TITLE", "Random Facts API")


def get_language() -> str:
    """Get the language from environment variable or default to 'en'."""
    return os.getenv("APP_LANGUAGE", "en")


@app.after_request
def log_request(response: Response) -> Response:
    """Log request and response details in JSON format."""
    log_data = {
        "method": request.method,
        "path": request.path,
        "status": response.status_code,
        "remote_addr": request.remote_addr,
    }
    logger.info(json.dumps(log_data))
    return response


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
        logger.error(json.dumps({"error": str(e)}))
        return Response(f"<h3>Error: {str(e)}</h3>", mimetype="text/html", status=500)


@app.route("/healthz")
def healthz() -> Response:
    """Health check endpoint."""
    return Response("<h3>Status: Ready</h3>", mimetype="text/html")


@app.route("/failcheck")
def failcheck() -> Response:
    """Liveness check endpoint."""
    return Response("<h3>Status: Alive</h3>", mimetype="text/html")


if __name__ == "__main__":
    host = "127.0.0.1"
    port = int(os.getenv("FLASK_RUN_PORT", "5000"))
    app.run(host=host, port=port)
