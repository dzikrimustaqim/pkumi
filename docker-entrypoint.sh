#!/bin/sh

set -e

echo "[INFO] Starting PKUMI Application..."

# Wait for database
echo "[INFO] Waiting for database..."
max_retries=30
counter=0

while [ $counter -lt $max_retries ]; do
    if php artisan db:show > /dev/null 2>&1; then
        echo "[INFO] Database connected!"
        break
    fi
    counter=$((counter + 1))
    echo "[INFO] Waiting for database... ($counter/$max_retries)"
    sleep 2
done

if [ $counter -eq $max_retries ]; then
    echo "[ERROR] Could not connect to database"
    exit 1
fi

# Generate APP_KEY if not set
if [ -z "$APP_KEY" ] || [ "$APP_KEY" = "base64:" ]; then
    echo "[INFO] Generating APP_KEY..."
    export APP_KEY=$(php artisan key:generate --show)
    echo "[INFO] Generated APP_KEY: ${APP_KEY:0:20}..."
fi

# Run migrations
echo "[INFO] Running migrations..."
php artisan migrate --force

# Optimize for production
echo "[INFO] Optimizing application..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Create storage link
if [ ! -L public/storage ]; then
    echo "[INFO] Creating storage link..."
    php artisan storage:link 2>/dev/null || true
fi

# Fix permissions
echo "[INFO] Setting permissions..."
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

echo "[INFO] Application ready!"

# Execute CMD
exec "$@"
