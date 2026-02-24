#!/bin/bash
set -e

cd /opt/netbox/netbox

echo "==> Starting RQ Worker..."
echo "    Listening on queues: default, high, low"

exec python manage.py rqworker high default low
