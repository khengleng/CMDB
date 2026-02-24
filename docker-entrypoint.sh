#!/bin/bash
set -e

cd /opt/netbox/netbox

echo "==> Running database migrations..."
python manage.py migrate --no-input

echo "==> Removing stale content types..."
python manage.py remove_stale_contenttypes --no-input || true

echo "==> Building search index (lazy)..."
python manage.py reindex --lazy || true

# Create superuser from env vars if provided
if [ -n "$SUPERUSER_NAME" ] && [ -n "$SUPERUSER_EMAIL" ] && [ -n "$SUPERUSER_PASSWORD" ]; then
    echo "==> Creating/updating superuser..."
    # Use Django's built-in --noinput flag which reads DJANGO_SUPERUSER_PASSWORD
    # from env. This avoids shell injection from special characters in passwords.
    export DJANGO_SUPERUSER_PASSWORD="$SUPERUSER_PASSWORD"
    python manage.py createsuperuser --no-input \
        --username "$SUPERUSER_NAME" \
        --email "$SUPERUSER_EMAIL" 2>/dev/null || \
        echo "Superuser already exists: $SUPERUSER_NAME"
    unset DJANGO_SUPERUSER_PASSWORD
fi

echo "==> Collecting static files..."
python manage.py collectstatic --no-input || true

echo "==> Starting Gunicorn on port ${PORT:-8000}..."
exec gunicorn netbox.wsgi:application \
    --bind "0.0.0.0:${PORT:-8000}" \
    --workers "${GUNICORN_WORKERS:-3}" \
    --threads "${GUNICORN_THREADS:-3}" \
    --timeout "${GUNICORN_TIMEOUT:-120}" \
    --max-requests 5000 \
    --max-requests-jitter 500 \
    --access-logfile - \
    --error-logfile -
