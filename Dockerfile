FROM php:8.3-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    mysql-client \
    libpng libjpeg-turbo freetype libzip icu-libs oniguruma

# Install PHP build dependencies and extensions
RUN apk add --no-cache --virtual .build-deps \
    libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev icu-dev oniguruma-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) pdo_mysql mbstring exif pcntl bcmath gd zip intl opcache \
    && apk del .build-deps

# Copy Composer from official image
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Configure PHP
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=128" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "memory_limit=256M" >> /usr/local/etc/php/conf.d/php.ini \
    && echo "upload_max_filesize=20M" >> /usr/local/etc/php/conf.d/php.ini \
    && echo "post_max_size=20M" >> /usr/local/etc/php/conf.d/php.ini

# Configure Supervisor
RUN echo '[supervisord]' > /etc/supervisord.conf \
    && echo 'nodaemon=true' >> /etc/supervisord.conf \
    && echo 'user=root' >> /etc/supervisord.conf \
    && echo 'logfile=/dev/stdout' >> /etc/supervisord.conf \
    && echo 'logfile_maxbytes=0' >> /etc/supervisord.conf \
    && echo '' >> /etc/supervisord.conf \
    && echo '[program:php-fpm]' >> /etc/supervisord.conf \
    && echo 'command=php-fpm -F' >> /etc/supervisord.conf \
    && echo 'stdout_logfile=/dev/stdout' >> /etc/supervisord.conf \
    && echo 'stdout_logfile_maxbytes=0' >> /etc/supervisord.conf \
    && echo 'stderr_logfile=/dev/stderr' >> /etc/supervisord.conf \
    && echo 'stderr_logfile_maxbytes=0' >> /etc/supervisord.conf \
    && echo '' >> /etc/supervisord.conf \
    && echo '[program:nginx]' >> /etc/supervisord.conf \
    && echo 'command=nginx -g "daemon off;"' >> /etc/supervisord.conf \
    && echo 'stdout_logfile=/dev/stdout' >> /etc/supervisord.conf \
    && echo 'stdout_logfile_maxbytes=0' >> /etc/supervisord.conf \
    && echo 'stderr_logfile=/dev/stderr' >> /etc/supervisord.conf \
    && echo 'stderr_logfile_maxbytes=0' >> /etc/supervisord.conf

# Copy Nginx config
COPY docker/nginx/default.conf /etc/nginx/http.d/default.conf

WORKDIR /var/www/html

# Copy application files
COPY . .

# Install Composer dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Setup directories and permissions
RUN mkdir -p storage/framework/{sessions,views,cache} bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Copy and set entrypoint
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && dos2unix /entrypoint.sh 2>/dev/null || sed -i 's/\r$//' /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
