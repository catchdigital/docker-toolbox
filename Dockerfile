FROM php:8.0-fpm
MAINTAINER Alberto Conteras <a.contreras@catchdigital.com>

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

# Install BCMath
RUN docker-php-ext-install bcmath

# Install node and npm
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get -y install nodejs && npm install -g npm@latest

## Install tools
# Install aws cli v2
RUN case $TARGETPLATFORM in \
  linux/amd64) \
    curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip \
    ;; \
  linux/arm64) \
    curl https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip -o awscliv2.zip \
    ;; \
  *) \
    echo "unsupported architecture"; exit 1 ;; \
esac

RUN unzip awscliv2.zip && \
    ./aws/install

# Install aws eb cli
# TODO: Adding 'LIBSODIUM_MAKE_ARGS=-j4' might speed up the install of pynacl
RUN LIBSODIUM_MAKE_ARGS=-j4 pip install awsebcli --upgrade --user
# RUN pip install awsebcli --upgrade --user

# Clean up aws files.
RUN rm -Rf awscliv2.zip aws

# Install aws cdk and aws amplify cli
RUN npm install -g aws-cdk @aws-amplify/cli

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
ENV COMPOSER_HOME '/usr/composer'

# Clean up installations
RUN apt-get -y autoremove && apt-get -y clean

# Set directory and working permissions
WORKDIR /var/www
ENV PATH=/var/www/vendor/bin:${PATH}

# Set www-data user
RUN usermod -u 1000 www-data && \
   usermod -g users www-data && \
   chown -R www-data:www-data /var/www
