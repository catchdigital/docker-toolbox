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

# Install BCMath
RUN docker-php-ext-install bcmath

# Upadte memory limit for php
RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/memory-limit.ini

# Install node and npm
## Download and import the Nodesource GPG key
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
## Create deb repository
RUN NODE_MAJOR=20 &&\
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
## Run Update and Install
RUN apt update && apt install -y nodejs

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
