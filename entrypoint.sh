#!/bin/sh

set -e

echo "Starting entrypoint script..."

# Start nginx in the background
echo "Starting Nginx..."
nginx -g 'daemon off;' &

# Start the proxy in the background
echo "Starting pmoxs3backuproxy..."
/pmoxs3backuproxy "$@" &

# Start supercronic in the foreground, which will handle the cron jobs
echo "Starting supercronic..."
exec /usr/local/bin/supercronic /etc/nginx/crontab