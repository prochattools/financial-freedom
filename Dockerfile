# ------------------------
# Frontend build stage
# ------------------------
FROM node:20 AS frontend
WORKDIR /app

# Copy package files & install dependencies
COPY package*.json vite.config.js ./
RUN npm install

# Copy the rest of the code (needed for ziggy imports)
COPY . .

# Build assets
RUN npm run build

# ------------------------
# PHP + Composer build stage
# ------------------------
FROM php:8.3-fpm AS backend

# Install system deps + PHP extensions
RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libzip-dev libonig-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

# Copy full app code (artisan included)
COPY . .

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install PHP dependencies
RUN composer install --no-dev --no-interaction --optimize-autoloader

# Prepare Laravel dirs
RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# ------------------------
# Final runtime
# ------------------------
FROM backend AS final

# Copy frontend build into public/
COPY --from=frontend /app/public/build /var/www/html/public/build

# Copy nginx & supervisord configs
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
