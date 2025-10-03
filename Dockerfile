# ─────────── Frontend build (needs vendor for Ziggy) ───────────
FROM php:8.3-fpm AS phpdeps
WORKDIR /app

# OS deps for Composer
RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libonig-dev \
 && docker-php-ext-install pdo pdo_mysql zip \
 && rm -rf /var/lib/apt/lists/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer \
  | php -- --install-dir=/usr/local/bin --filename=composer

# Bring in full app BEFORE composer so artisan exists
COPY . ./

# Install PHP deps without dev (artisan available now)
RUN composer install --no-dev --no-interaction --optimize-autoloader

# ─────────── Vite build ───────────
FROM node:20 AS frontend
WORKDIR /app

# Copy only what Vite needs + vendor (for Ziggy import)
COPY package*.json vite.config.js ./
COPY resources ./resources
COPY public ./public
COPY --from=phpdeps /app/vendor ./vendor

# Build static assets
RUN npm ci || npm install
RUN npm run build

# ─────────── Final runtime (nginx + php-fpm) ───────────
FROM php:8.3-fpm AS runtime
WORKDIR /var/www/html

# OS + nginx + supervisor
RUN apt-get update && apt-get install -y \
    nginx supervisor curl \
 && docker-php-ext-install pdo pdo_mysql zip \
 && rm -rf /var/lib/apt/lists/*

# Copy full app and composer vendor
COPY . ./
COPY --from=phpdeps /app/vendor ./vendor

# Copy built assets
COPY --from=frontend /app/public/build ./public/build

# Make storage/cache writable
RUN mkdir -p storage bootstrap/cache \
 && chown -R www-data:www-data storage bootstrap/cache \
 && chmod -R 775 storage bootstrap/cache

# nginx + supervisor configs
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 80
CMD ["/usr/bin/supervisord","-n","-c","/etc/supervisor/conf.d/supervisord.conf"]
