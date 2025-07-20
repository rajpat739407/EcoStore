FROM php:8.2-apache

# 1. Install system dependencies including unzip (required for Composer)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Install PHP extensions
RUN docker-php-ext-install pdo pdo_mysql mbstring zip

# 3. Install Composer properly
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# 4. Set working directory
WORKDIR /var/www/html

# 5. Copy composer files first for caching
COPY composer.json composer.lock ./

# 6. Install dependencies (with error handling)
RUN composer install --no-dev --optimize-autoloader --no-scripts || \
    (echo "Composer install failed, trying with memory limit" && \
    COMPOSER_MEMORY_LIMIT=-1 composer install --no-dev --optimize-autoloader --no-scripts)

# 7. Copy the rest of the application
COPY . .

# 8. Set permissions
RUN mkdir -p storage/framework/{sessions,views,cache} bootstrap/cache && \
    chown -R www-data:www-data storage bootstrap/cache && \
    chmod -R 775 storage bootstrap/cache

# 9. Apache configuration
COPY ./000-default.conf /etc/apache2/sites-available/000-default.conf
RUN a2enmod rewrite
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf

# 10. Generate application key
RUN php artisan key:generate --force
