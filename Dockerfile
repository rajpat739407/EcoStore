FROM php:8.2-apache

# 1. Install system dependencies (added missing ones for PHP extensions)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libwebp-dev \  # For GD with WebP support
    zlib1g-dev \
    libicu-dev \   # For intl extension if needed
    libpq-dev \    # For PostgreSQL (optional)
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 2. Install PHP extensions in separate steps for better error handling
# First install dependencies for gd
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp

# Then install all extensions
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    opcache

# 3. Fix PDO duplicate loading
RUN rm -f /usr/local/etc/php/conf.d/docker-php-ext-pdo.ini && \
    docker-php-ext-enable pdo_mysql

# 4. Apache configuration
RUN a2enmod rewrite headers && \
    echo "DirectoryIndex index.php index.html" > /etc/apache2/conf-enabled/directory-index.conf

# 5. Set working directory
WORKDIR /var/www/html

# 6. Install Composer (multi-stage to reduce image size)
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 7. Copy composer files first for caching
COPY composer.lock composer.json ./

# 8. Install dependencies (no dev for production)
RUN composer install --no-dev --optimize-autoloader --no-scripts

# 9. Copy application files
COPY . .

# 10. Set permissions
RUN chown -R www-data:www-data storage bootstrap/cache && \
    chmod -R 775 storage bootstrap/cache

# 11. Apache config
COPY ./000-default.conf /etc/apache2/sites-available/000-default.conf

# 12. Set document root
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf && \
    sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# 13. Generate Laravel key
RUN php artisan key:generate --force
