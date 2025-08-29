FROM python:3.11-slim AS builder

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.11-slim

WORKDIR /app

# Create non-root user
RUN addgroup --system app && adduser --system --ingroup app app

# Copy installed packages from builder stage
COPY --from=builder /install /usr/local

# Copy app code
COPY app.py ./

# Ensure non-root ownership
RUN chown -R app:app /app
USER app

# Expose Flask port
EXPOSE 5000

# Run with gunicorn (production) instead of flask dev server
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
