# Stage 1: PHP dependencies with Composer
FROM composer:2 as vendor

WORKDIR /app

# Copy composer files first (better layer caching)
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --optimize-autoloader --ignore-platform-reqs

# Copy the rest of the app
COPY . .

# Stage 2: Node build for frontend (if you have Vue/React in the repo)
FROM node:20 as frontend
WORKDIR /app

COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build || echo "⚠️ Frontend build failed, continuing..."

# Stage 3: Final PHP + Nginx container
FROM php:8.3-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libonig-dev libzip-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

# Copy Composer dependencies from vendor stage
COPY --from=vendor /app /var/www/html

# Copy built frontend (public assets) if any
COPY --from=frontend /app/public /var/www/html/public

# Set working directory
WORKDIR /var/www/html

# Make storage & cache writable
RUN mkdir -p storage bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Copy config files
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80

CMD ["/usr/bin/supervisord"]
