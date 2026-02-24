#!/bin/bash
set -e

cd /opt/netbox/netbox

echo "==> Starting Housekeeping Scheduler..."
echo "    Running periodic maintenance tasks every 15 minutes"

# Run housekeeping tasks in a loop
while true; do
    echo "[$(date)] Running housekeeping tasks..."

    # Clear expired sessions
    echo "  -> Clearing expired sessions..."
    python manage.py clearsessions 2>/dev/null || true

    if [ "${REMOVE_STALE_CONTENTTYPES:-false}" = "true" ]; then
        # Remove stale content types
        echo "  -> Removing stale content types..."
        python manage.py remove_stale_contenttypes --no-input 2>/dev/null || true
    fi

    # Clean up expired object changes (changelog) older than configured retention
    echo "  -> Cleaning up old change log entries..."
    python manage.py housekeeping 2>/dev/null || true

    # Rebuild the search index (lazy mode — only new/changed objects)
    echo "  -> Updating search index..."
    python manage.py reindex --lazy 2>/dev/null || true

    echo "[$(date)] Housekeeping complete. Sleeping 15 minutes..."
    sleep 900
done
