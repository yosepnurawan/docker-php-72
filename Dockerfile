FROM php:7.2-apache-stretch
LABEL maintainer="Yosep Nurawan <yosepnurawan.official@gmail.com>"

RUN apt-get update -y -qq && \
    apt-get install -y -qq \
        zlib1g-dev \
        libicu-dev \
        libaio-dev \
        libmcrypt-dev \
        g++ \
        git \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        unzip \
        && apt-get clean -y

RUN docker-php-ext-configure intl
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include --with-jpeg-dir=/usr/include
RUN docker-php-ext-install intl mysqli pdo pdo_mysql gd

RUN apt-get update -qq \
    && apt-get install -y -qq libmemcached-dev \
    && pecl install memcached-3.0.4 \
    && docker-php-ext-enable memcached

# apache configurations, mod rewrite
RUN ln -s /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load

# install composer
RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
  && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
  && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }"

# Oracle instantclient
# copy oracle files
ADD oracle/instantclient-basic-linux.x64-12.1.0.2.0.zip /tmp/
ADD oracle/instantclient-sdk-linux.x64-12.1.0.2.0.zip /tmp/
ADD oracle/instantclient-sqlplus-linux.x64-12.1.0.2.0.zip /tmp/

# unzip them
RUN unzip /tmp/instantclient-basic-linux.x64-12.1.0.2.0.zip -d /usr/local/ \
    && unzip /tmp/instantclient-sdk-linux.x64-12.1.0.2.0.zip -d /usr/local/ \
    && unzip /tmp/instantclient-sqlplus-linux.x64-12.1.0.2.0.zip -d /usr/local/

# install pecl
RUN curl -O http://pear.php.net/go-pear.phar \
    ; /usr/local/bin/php -d detect_unicode=0 go-pear.phar

# install oci8
RUN ln -s /usr/local/instantclient_12_1 /usr/local/instantclient \
    && ln -s /usr/local/instantclient/libclntsh.so.12.1 /usr/local/instantclient/libclntsh.so \
    # tambahan pdo
    && ln -s /usr/local/instantclient/libclntshcore.so.12.1 /usr/local/instantclient/libclntshcore.so \
    && ln -s /usr/local/instantclient/libocci.so.12.1 /usr/local/instantclient/libocci.so \
    && echo 'instantclient,/usr/local/instantclient/' | pecl install oci8 \
    && ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus 

# Install Oracle extensions
# tambahan pdo
RUN docker-php-ext-configure pdo_oci --with-pdo-oci=instantclient,/usr/local/instantclient \
       && docker-php-ext-install \
               pdo_oci \
       && docker-php-ext-enable \
               oci8

ENV LD_LIBRARY_PATH /usr/local/instantclient_12_1/

RUN a2enmod rewrite

ADD . /var/www/html
EXPOSE 80
