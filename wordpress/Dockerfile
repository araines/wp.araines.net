FROM wordpress:php8.2-apache

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN apt-get update && apt-get install -y sudo jq awscli mariadb-client curl zip git

# Download and install wp-cli
RUN cd /tmp && \
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Download and install composer
RUN cd /tmp && \
  curl -o composer-setup.php https://getcomposer.org/installer && \
  php composer-setup.php && \
  rm composer-setup.php && \
  mv composer.phar /usr/local/bin/composer

# Copy custom PHP ini directives
COPY wordpress.ini $PHP_INI_DIR/conf.d/

# Copy needed files for running
COPY apache2-entrypoint.sh /usr/local/bin
COPY composer.json /tmp/

CMD ["apache2-entrypoint.sh"]
