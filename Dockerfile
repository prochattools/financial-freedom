# =========================================
# Frontend build (Vite + Node)
# =========================================
FROM node:20 AS frontend
WORKDIR /app

COPY package*.json vite.config.js ./
COPY resources ./resources
COPY public ./public

RUN npm ci || npm install
RUN npm run build

# =========================================
# PHP dependencies (Composer install)
# =========================================
FROM php:8.3-fpm AS phpdeps
WORKDIR /app

# Needed system libs for PHP extensions + composer
RUN apt-get update && apt-get install -y \
    git unzip libzip-dev curl \
 && rm -rf /var/lib/apt/lists/*

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY . ./
RUN composer install --no-dev --no-interaction --optimize-autoloader

# =========================================
# Runtime (Nginx + PHP-FPM + Supervisor)
# =========================================
FROM php:8.3-fpm AS runtime
WORKDIR /var/www/html

# OS packages + PHP extensions
RUN apt-get update && apt-get install -y \
    nginx supervisor curl libzip-dev unzip git \
 && docker-php-ext-configure zip \
 && docker-php-ext-install pdo pdo_mysql zip \
 && rm -rf /var/lib/apt/lists/*

# Copy app code
COPY --from=phpdeps /app ./
COPY --from=frontend /app/public/build ./public/build

# Nginx config
COPY deploy/docker/nginx.conf /etc/nginx/nginx.conf
COPY deploy/docker/default.conf /etc/nginx/sites-enabled/default

# Supervisor config (to run PHP-FPM + Nginx together)
COPY deploy/docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80
CMD ["supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
