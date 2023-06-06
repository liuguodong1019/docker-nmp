FROM php:8.0-fpm as php8.0
RUN apt-get update && apt-get install -y \
               libfreetype6-dev \
               libjpeg62-turbo-dev \
               libpng-dev \
	       libmemcached-dev \
	       zlib1g-dev \
	&& docker-php-ext-configure gd --with-freetype --with-jpeg \
	&& docker-php-ext-install -j$(nproc) gd \
	&& pecl install redis \
	memcached \
	xdebug \
	&& docker-php-ext-enable redis \
	memcached \
	xdebug \
	opcache \
	&& docker-php-ext-install bcmath

FROM nginx as nginx

FROM mysql:latest as mysql
ENV MYSQL_ROOT_PASSWORD=123456


FROM golang as goweb
WORKDIR /app
ENV GOPROXY https://goproxy.cn
COPY meeting-master/ .
RUN go mod download \
        && cd cmd \
        && CGO_ENABLED=0 GOOS=linux go build -o /mt
FROM scratch AS web
WORKDIR /
COPY --from=goweb /mt /mt
ENTRYPOINT ["/mt"]
