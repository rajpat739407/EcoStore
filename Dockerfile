FROM php:8.2-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git curl libpng-dev zip unzip libonig-dev libxml2-dev libzip-dev \
    && docker-php-ext-install pdo pdo_mysql zip

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Set working directory
WORKDIR /var/www/html

# Copy Laravel app
COPY . /var/www/html

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Add this line before the composer install command
RUN docker-php-ext-install exif

# Install dependencies
RUN composer install --optimize-autoloader --no-dev --ignore-platform-req=ext-exif

# Copy custom Apache config
COPY ./000-default.conf /etc/apache2/sites-available/000-default.conf
