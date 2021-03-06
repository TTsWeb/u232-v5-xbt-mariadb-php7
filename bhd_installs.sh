#!/bin/bash
wget -q http://www.webmin.com/jcameron-key.asc -O- | sudo apt-key add -
apt-get install ca-certificates wget sudo -y
apt-get -y install mariadb-server apache2 memcached unzip libssl-dev php7.0 libapache2-mod-php7.0 php7.0-mysql php7.0-curl php7.0-gd php-pear php7.0-imagick php7.0-imap php7.0-mcrypt php7.0-memcached php7.0-pspell php7.0-recode php7.0-sqlite3 php7.0-tidy php7.0-xmlrpc php7.0-xsl php7.0-json php7.0-cgi php7.0-dev libmariadbclient-dev apache2-dev php7.0-curl libcurl3 curl tcl8.5 locate libperl-dev php7.0-mcrypt libmemcached-tools
wget https://www.cloudflare.com/static/misc/mod_cloudflare/debian/mod_cloudflare-jessie-amd64.latest.deb
dpkg -i mod_cloudflare-jessie-amd64.latest.deb
sudo apt-get install make gcc build-essential openssl libcurl4-openssl-dev zlib1g zlib1g-dev zlibc libgcrypt11-dev -y
apt-get install mysqltcl tcl tcl-dev tcl8.5 tcl8.5-dev tk tk-dev tk8.5 tk8.5-dev tcl-doc tclreadline tcl8.5-doc tk-doc tk8.5-doc mesa-utils gnutls-bin libgnutls28-dev-y
sudo apt-get -y install libmysql++-dev libpng-dev libmcrypt-dev libxml2-dev memcached sphinxsearch binutils libev-dev git php-soap php-pear php7.0-memcache php7.0-curl php7.0-mysql php7.0-mcrypt php7.0-gd sendmail
sudo apt-get -y install libboost-all-dev libboost-iostreams-dev libev-dev screen make g++ libbz2-dev libtcmalloc-minimal4
sudo apt-get -y install gcc g++ libevent-dev default-libmysqlclient-dev libmysql++6 libmysql++-dev
sudo apt-get -y install libboost-all-dev libboost-iostreams-dev libboost-fiber-dev libboost-type-erasure-dev libboost-date-time1.62-dev libboost-iostreams1.62-dev libboost-log1.62-dev libboost-thread1.62-dev libboost-wave1.62-dev 
apt-get install webmin -y
