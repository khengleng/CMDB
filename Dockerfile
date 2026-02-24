FROM python:3.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    NETBOX_CONFIGURATION=netbox.configuration

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libffi-dev \
    libpq-dev \
    libxml2-dev \
    libxslt1-dev \
    libjpeg62-turbo-dev \
    libopenjp2-7-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/netbox

# Copy requirements first for layer caching
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip wheel && \
    pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

WORKDIR /opt/netbox/netbox

# Collect static files (needs a dummy SECRET_KEY)
RUN SECRET_KEY="dummy-key-for-collectstatic-only-not-for-production" \
    ALLOWED_HOSTS="*" \
    REDIS_URL="redis://localhost:6379" \
    DATABASE_URL="postgresql://localhost/netbox" \
    python manage.py collectstatic --no-input 2>/dev/null || true

# Copy entrypoint
COPY docker-entrypoint.sh /opt/netbox/docker-entrypoint.sh
RUN chmod +x /opt/netbox/docker-entrypoint.sh

EXPOSE ${PORT:-8000}

ENTRYPOINT ["/opt/netbox/docker-entrypoint.sh"]
