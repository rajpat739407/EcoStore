FROM php:8.2-apache

# [Previous installation commands...]

WORKDIR /var/www/html

# 1. First copy only composer files for caching
COPY composer.lock composer.json ./

# 2. Install dependencies
RUN composer install --no-dev --optimize-autoloader --no-scripts

# 3. Copy ALL files
COPY . .

# 4. THIS IS WHERE THE PERMISSION COMMANDS GO (right after COPY . .)
RUN set -ex; \
    # Ensure directories exist
    mkdir -p storage/framework/{sessions,views,cache} bootstrap/cache; \
    # Set ownership
    chown -R www-data:www-data storage bootstrap/cache; \
    # Set permissions
    chmod -R 775 storage bootstrap/cache; \
    # Special handling for bootstrap files
    chmod 644 bootstrap/*.php; \
    chmod 644 bootstrap/.gitignore;

# [Rest of your Dockerfile...]
COPY ./000-default.conf /etc/apache2/sites-available/000-default.conf
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN php artisan key:generate --force
