FROM php:8.2-apache

# 1. Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libwebp-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && \
    docker-php-ext-install pdo pdo_mysql mbstring exif pcntl bcmath gd zip

# 3. Install Composer (official method)
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

# 4. Set working directory
WORKDIR /var/www/html

# 5. Copy composer files first
COPY composer.json composer.lock ./

# 6. Install dependencies with multiple fallbacks
RUN { \
    composer install --no-dev --optimize-autoloader --no-scripts || \
    { \
        echo "First attempt failed, retrying with memory limit" && \
        COMPOSER_MEMORY_LIMIT=-1 composer install --no-dev --optimize-autoloader --no-scripts || \
        { \
            echo "Second attempt failed, trying with different stability" && \
            composer install --no-dev --optimize-autoloader --no-scripts --ignore-platform-reqs; \
        }; \
    }; \
}

# 7. Copy application files
COPY . .

# 8. Set permissions
RUN mkdir -p storage/framework/{sessions,views,cache} bootstrap/cache && \
    chown -R www-data:www-data storage bootstrap/cache && \
    chmod -R 775 storage bootstrap/cache

# 9. Apache configuration
COPY ./000-default.conf /etc/apache2/sites-available/000-default.conf
RUN a2enmod rewrite
# Replace your current DocumentRoot setting with:
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html(/)?!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/sites-available/*.conf \
    /etc/apache2/apache2.conf \
    /etc/apache2/conf-available/*.conf

# 10. Generate application key
# After COPY . . and permission settings
RUN if [ ! -f .env ]; then \
        echo "Creating .env file from example"; \
        cp .env.example .env; \
        php artisan key:generate --force; \
    else \
        echo "Existing .env found, generating key"; \
        php artisan key:generate --force || \
        echo "Key generation failed (may already be set)"; \
    fi
