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
    python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='${SUPERUSER_NAME}').exists():
    User.objects.create_superuser('${SUPERUSER_NAME}', '${SUPERUSER_EMAIL}', '${SUPERUSER_PASSWORD}')
    print('Superuser created: ${SUPERUSER_NAME}')
else:
    print('Superuser already exists: ${SUPERUSER_NAME}')
"
fi

echo "==> Collecting static files..."
python manage.py collectstatic --no-input

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
