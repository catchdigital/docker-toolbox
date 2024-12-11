FROM php:8.3-fpm
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
RUN apt update \
    && apt install -y \
    less \
    groff \
    jq \
    git \
    curl \
    rsync \
    ssh \
    python3 \
    python3-pip \
    zip \
    libzip-dev \
    gnupg2 \
    ca-certificates \
    xdg-utils

# Install GD and other dependencies
RUN apt install -y \
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

# Add Python 2.7 from archive
RUN echo "deb http://archive.debian.org/debian/ stretch main" > /etc/apt/sources.list.d/stretch.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    python2.7 \
    python2.7-dev \
    curl

# Add symbolic link for python command
RUN ln -s /usr/bin/python2.7 /usr/bin/python2

# Install BCMath
RUN docker-php-ext-install bcmath

# Upadte memory limit for php
RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/memory-limit.ini

# Install NVM, Node.js and NPM
ENV NVM_DIR /root/.nvm
ENV NODE_VERSION 20.18.1

RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    nvm use default

ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

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
# RUN git clone https://github.com/aws/aws-elastic-beanstalk-cli-setup.git
# RUN apt install -y python3-virtualenv
# RUN python3 ./aws-elastic-beanstalk-cli-setup/scripts/ebcli_installer.py
# ENV PATH=/root/.ebcli-virtual-env/executables:${PATH}
RUN pip install awsebcli --upgrade --user --break-system-packages

# Install Ansible
RUN python3 -m pip install --user ansible-core --break-system-packages
ENV PATH=/root/.local/bin:${PATH}

# Clean up aws files.
RUN rm -Rf awscliv2.zip aws

# Install aws cdk and aws amplify cli
RUN npm install -g aws-cdk @aws-amplify/cli

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
ENV COMPOSER_HOME='/usr/composer'

# Add Acquia CLI
RUN curl -OL https://github.com/acquia/cli/releases/latest/download/acli.phar && \
    chmod +x acli.phar && \
    mv acli.phar /usr/local/bin/acli

# Clean up installations
RUN apt-get -y autoremove && apt-get -y clean

# Set directory and working permissions
WORKDIR /var/www
ENV PATH=/var/www/vendor/bin:${PATH}

# Set www-data user
RUN usermod -u 1000 www-data && \
   usermod -g users www-data && \
   chown -R www-data:www-data /var/www
