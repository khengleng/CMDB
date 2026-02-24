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

# Create non-root user for running the application
RUN groupadd -r netbox && useradd -r -g netbox -d /opt/netbox -s /sbin/nologin netbox

WORKDIR /opt/netbox

# Copy requirements first for layer caching
COPY requirements.txt local_requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip wheel && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -r local_requirements.txt

# Copy the rest of the application
COPY . .

WORKDIR /opt/netbox/netbox

# Collect static files (needs a dummy SECRET_KEY >= 50 chars)
RUN SECRET_KEY="build-only-dummy-secret-key-that-is-at-least-fifty-characters-long-for-collectstatic" \
    ALLOWED_HOSTS="*" \
    REDIS_URL="redis://localhost:6379" \
    DATABASE_URL="postgresql://localhost/netbox" \
    python manage.py collectstatic --no-input 2>/dev/null || true

# Copy entrypoint and set permissions
COPY docker-entrypoint.sh /opt/netbox/docker-entrypoint.sh
RUN chmod +x /opt/netbox/docker-entrypoint.sh

# Ensure netbox user owns the app directory (needed for writing logs, media, etc.)
RUN chown -R netbox:netbox /opt/netbox

# Switch to non-root user
USER netbox

EXPOSE ${PORT:-8000}

ENTRYPOINT ["/opt/netbox/docker-entrypoint.sh"]
