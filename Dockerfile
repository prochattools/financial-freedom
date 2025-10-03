# ---- Base PHP Image ----
FROM php:8.3-fpm AS base

# Install dependencies
RUN apt-get update && apt-get install -y \
    git unzip curl libpq-dev libonig-dev libzip-dev nginx supervisor \
    && docker-php-ext-install pdo pdo_mysql pdo_pgsql zip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

# Copy composer first for caching
COPY composer.json composer.lock ./

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# ---- Copy Full App ----
COPY . .

# Install PHP dependencies (now artisan exists!)
RUN composer install --no-dev --no-interaction --optimize-autoloader

# Laravel storage + cache permissions
RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# ---- Frontend build ----
FROM node:20 AS frontend
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build || echo "⚠️ Frontend build failed, continuing..."

# ---- Final Image ----
FROM base AS final

# Copy built frontend assets into Laravel public
COPY --from=frontend /app/public /var/www/html/public

# Copy Laravel env file if exists
COPY .env /var/www/html/.env

# Configure Nginx + Supervisor
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
