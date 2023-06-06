FROM php:8.1-fpm
LABEL org.opencontainers.image.authors="a.contreras@catchdigital.com"

# Get build target.
ARG TARGETPLATFORM

# Supported architectures.
RUN case $TARGETPLATFORM in \
  linux/amd64) ARCH='x86_64';; \
  linux/arm64) ARCH='aarch64';; \
  *) echo "unsupported architecture"; exit 1 ;; \
esac

## Install dependencies
RUN apt-get update \
    && apt-get install -y \
    less \
    groff \
    jq \
    git \
    curl \
    rsync \
    ssh \
    python \
    python3 \
    python3-pip \
    zip \
    libzip-dev \
    gnupg2

# Install GD and other dependencies
RUN apt-get install -y \
        libjpeg-dev \
        libpng-dev \
        libjpeg62-turbo \
        libfreetype6-dev && \
  docker-php-ext-configure gd \
    --with-freetype=/usr/include/ \
    --with-jpeg=/usr/include/ && \
  NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) && \
  docker-php-ext-install -j${NPROC} gd zip && \
  apt-get remove -y libfreetype6-dev libpng-dev libfreetype6-dev

# Install node and npm
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get -y install nodejs && npm install -g npm@latest

# Clean up installations
RUN apt-get -y autoremove && apt-get -y clean

# Set directory and working permissions
WORKDIR /var/www
ENV PATH=/var/www/vendor/bin:${PATH}

# Set www-data user
RUN usermod -u 1000 www-data && \
   usermod -g users www-data && \
   chown -R www-data:www-data /var/www
