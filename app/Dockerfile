FROM python:3.13-slim AS builder

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.13-slim

WORKDIR /app

RUN addgroup --system app && adduser --system --ingroup app app

COPY --from=builder /install /usr/local

COPY app.py ./

RUN chown -R app:app /app
USER app

EXPOSE 5000

# nosec B104 - Binding to 0.0.0.0 is required inside Kubernetes
CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${FLASK_RUN_PORT:-5000} app:app"]
