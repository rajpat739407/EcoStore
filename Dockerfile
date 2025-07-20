FROM php:8.2-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions with PDO fix
RUN docker-php-ext-install pdo pdo_mysql mbstring exif pcntl bcmath gd zip \
    && sed -i '/extension=pdo/d' /usr/local/etc/php/conf.d/docker-php-ext-pdo.ini \
    && a2enmod rewrite

# Configure Apache
RUN echo "DirectoryIndex index.php index.html" > /etc/apache2/conf-enabled/directory-index.conf

# Set working directory
WORKDIR /var/www/html

# Copy composer.lock and composer.json first for better caching
COPY composer.lock composer.json ./

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install dependencies (no dev dependencies for production)
RUN composer install --no-dev --optimize-autoloader --no-scripts

# Copy the rest of the application
COPY . .

# Set permissions for Laravel
RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Copy custom Apache config
COPY ./000-default.conf /etc/apache2/sites-available/000-default.conf

# Set Apache document root to Laravel's public directory
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Generate Laravel key and optimize
RUN php artisan key:generate --force \
    && php artisan optimize:clear
