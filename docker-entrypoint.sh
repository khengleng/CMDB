#!/bin/bash
set -e

cd /opt/netbox/netbox

echo "==> Running database migrations..."
python manage.py migrate --no-input

if [ "${REMOVE_STALE_CONTENTTYPES:-false}" = "true" ]; then
    echo "==> Removing stale content types..."
    python manage.py remove_stale_contenttypes --no-input
fi

echo "==> Building search index (lazy)..."
python manage.py reindex --lazy || true

# Create superuser from env vars if provided
if [ -n "$SUPERUSER_NAME" ] && [ -n "$SUPERUSER_EMAIL" ] && [ -n "$SUPERUSER_PASSWORD" ]; then
    echo "==> Ensuring superuser exists..."
    # Use Django's built-in --noinput flag which reads DJANGO_SUPERUSER_PASSWORD
    # from env. This avoids shell injection from special characters in passwords.
    if python manage.py shell -c "from django.contrib.auth import get_user_model; import os, sys; sys.exit(0 if get_user_model().objects.filter(username=os.environ['SUPERUSER_NAME']).exists() else 1)"; then
        echo "Superuser already exists: $SUPERUSER_NAME"
    else
        export DJANGO_SUPERUSER_PASSWORD="$SUPERUSER_PASSWORD"
        python manage.py createsuperuser --no-input \
            --username "$SUPERUSER_NAME" \
            --email "$SUPERUSER_EMAIL"
        unset DJANGO_SUPERUSER_PASSWORD
    fi
fi

echo "==> Collecting static files..."
if [ "${IGNORE_COLLECTSTATIC_ERRORS:-false}" = "true" ]; then
    python manage.py collectstatic --no-input || true
else
    python manage.py collectstatic --no-input
fi

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
