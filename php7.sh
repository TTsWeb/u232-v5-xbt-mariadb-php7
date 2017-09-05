#!/bin/bash
if [[ $EUID != 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi
STARTXBT='./xbt_tracker'
STARTMEMCACHED='service memcached restart'
STARTPHPFPM='service php7.0-fpm restart'
user='u232'
db='u232'
dbhost='localhost'
blank=''
announcebase='http:\/\/'
httpsannouncebase='https:\/\/'
announce2='\/announce.php'
xbt='xbt'
function randomString {
        local myStrLength=16;
        local mySeedNumber=$$`date +%N`;
        local myRandomString=$( echo $mySeedNumber | md5sum | md5sum );
        myRandomResult="${myRandomString:2:myStrLength}"
}

randomString;
pass=$myRandomResult
randomString;
pmakey=$myRandomResult
clear

echo 'This will install the absolute minimum requirements to get the site running'
echo -n "Enter the site's base url (with no http(s):// or www): "
read baseurl
echo -n "Enter the site's name: "
read name
echo -n "Enter the site's email: "
read email
echo -n "Do you want to enable SSL (y/n)
This will install a self-signed certificate: "
read ssl
echo -n "Do you want to install apache2 or nginx (apache2/nginx): "
read webserver
echo -n "Do you want to run XBT tracker or php? (xbt/php) "
read xbt
announce=$announcebase$baseurl$announce2
httpsannounce=$httpsannouncebase$baseurl$announce2
apt-get -y update
apt-get -y upgrade
apt-get -y install lsb-release
codename=$(lsb_release -a | grep Codename | awk '{ printf $2 }')

case $codename in
	"jessie")
        ;;
    *)
        echo `tput setaf 1``tput bold`"This OS is not yet supported! (EXITING)"`tput sgr0`
        echo
        exit 1
        ;;
esac
case $xbt in
    'xbt')
		extras='libmariadbclient-dev libpcre3 libpcre3-dev cmake g++ libboost-date-time-dev libboost-dev libboost-filesystem-dev libboost-program-options-dev libboost-regex-dev libboost-serialization-dev make subversion zlib1g-dev'
		announce=$announcebase$baseurl
        ;;
    'php')
        ;;
    *)
        echo`tput setaf 1``tput bold`"You did not enter a valid tracker type (EXITING)"`tput sgr0`
        echo
        exit 1
        ;;
esac

apt-get -y install software-properties-common
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
wget https://www.dotdeb.org/dotdeb.gpg
apt-key add dotdeb.gpg
rm dotdeb.gpg
add-apt-repository "deb http://packages.dotdeb.org jessie all"
add-apt-repository "deb [arch=amd64,i386] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.1/debian jessie main"
if [[ $webserver = 'nginx' ]]; then
	STARTWEBSERVER='service nginx restart'
	webpackages='php7.0-fpm nginx'
elif [[ $webserver = 'apache2' ]]; then
	STARTWEBSERVER='service apache2 restart'
	webpackages='libapache2-mod-php7.0 apache2'
fi

apt-get -y update
apt-get -y install mariadb-server memcached unzip libssl-dev php7.0 php7.0-mysql php7.0-json locate php7.0-memcached sendmail sendmail-bin $webpackages $extras

updatedb
mysql_secure_installation

cd ~
wget https://files.phpmyadmin.net/phpMyAdmin/4.5.4.1/phpMyAdmin-4.5.4.1-english.tar.gz
tar xfz phpMyAdmin-4.5.4.1-english.tar.gz
rm phpMyAdmin-4.5.4.1-english.tar.gz
mv phpMyAdmin-4.5.4.1-english /var/pma/
cd /var/pma/
cp config.sample.inc.php config.inc.php
sed -i "s/\$cfg\["\'"blowfish_secret"\'"\] \= "\'\'"\;/\$cfg\["\'"blowfish_secret"\'"\] \= "\'""$pmakey""\'"\;/" config.inc.php

if [[ $webserver = 'nginx' ]]; then
	cd /etc/nginx/sites-enabled
	sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/7.0/fpm/php.ini
	sed -i "s/user = www-data/user = www-data/" /etc/php/7.0/fpm/pool.d/www.conf
	sed -i "s/group = www-data/group = www-data/" /etc/php/7.0/fpm/pool.d/www.conf
	sed -i "s/;listen\.owner.*/listen.owner = www-data/" /etc/php/7.0/fpm/pool.d/www.conf
	sed -i "s/;listen\.group.*/listen.group = www-data/" /etc/php/7.0/fpm/pool.d/www.conf
	sed -i "s/;listen\.mode.*/listen.mode = 0660/" /etc/php/7.0/fpm/pool.d/www.conf # This passage in not required normally
	echo "memcached.serializer = 'php'" >> /etc/php/7.0/fpm/php.ini
	rm default*
	cd ../sites-available
	rm default*
	echo "server {
    listen 80 default_server;

    root /var/www;
    index index.html index.htm index.php;

    server_name $baseurl;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php7.0-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location /pma {
        root /var;
        index index.php index.html index.htm;
        location ~ ^/pma/(.+\.php)$ {
            try_files \$uri =404;
            root /var;
            fastcgi_pass unix:/run/php/php7.0-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include /etc/nginx/fastcgi_params;
        }

        location ~* ^/pma/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
            root /var;
        }
    }
}" > /etc/nginx/sites-available/default
	ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled
	$STARTWEBSERVER
	$STARTPHPFPM
elif [[ $webserver = 'apache2' ]]; then
	cd /etc/apache2/sites-enabled
	sed -i 's/\/var\/www\/html/\/var\/www/' 000-default*
	echo "memcached.serializer = 'php'" >> /etc/php/7.0/apache2/php.ini
    echo "<Directory /var/pma>
    Options FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
Alias /pma /var/pma" >> /etc/apache2/apache2.conf
	$STARTWEBSERVER
fi
cd ~
echo 'Please enter your root password for MYSQL when asked'
echo "create database $db;
grant all on $db.* to '$user'@'localhost'identified by '$pass';" > blah.sql
mysql -u root -p < blah.sql
rm blah.sql
wget https://github.com/Bigjoos/U-232-V4/archive/master.tar.gz
tar xfz master.tar.gz
cd U-232-V4-master
tar xfz pic.tar.gz
tar xfz GeoIP.tar.gz
tar xfz javairc.tar.gz
tar xfz Log_Viewer.tar.gz
cd /var
mkdir -p /var/bucket/avatar
cd /var/bucket
cp ~/U-232-V4-master/torrents/.htaccess .
cp ~/U-232-V4-master/torrents/index.* .
cd /var/bucket/avatar
cp ~/U-232-V4-master/torrents/.htaccess .
cp ~/U-232-V4-master/torrents/index.* .
cd ~
chmod -R 777 /var/bucket
cp -ar ~/U-232-V4-master/* /var/www
chmod -R 777 /var/www/cache
chmod 777 /var/www/dir_list
chmod 777 /var/www/uploads
chmod 777 /var/www/uploadsub
chmod 777 /var/www/imdb
chmod 777 /var/www/imdb/cache
chmod 777 /var/www/imdb/images
chmod 777 /var/www/include
chmod 777 /var/www/include/backup
chmod 777 /var/www/include/settings
echo > /var/www/include/settings/settings.txt
chmod 777 /var/www/include/settings/settings.txt
chmod 777 /var/www/sqlerr_logs/
chmod 777 /var/www/torrents
rm /var/www/include/class/class_cache.php
wget https://gitlab.open-scene.net/whocares/u232-v4-xbt-mariadb-php5/raw/master/class_cache.php -O /var/www/include/class/class_cache.php
configfile='/var/www/install/extra/config.'$xbt'sample.php'
sed 's/#mysql_user/'$user'/' $configfile > /var/www/include/config.php
sed -i 's/#mysql_pass/'$pass'/' /var/www/include/config.php
sed -i 's/#mysql_db/'$db'/' /var/www/include/config.php
sed -i 's/#mysql_host/'$dbhost'/' /var/www/include/config.php
sed -i 's/#cookie_prefix/'$blank'/' /var/www/include/config.php
sed -i 's/#cookie_path/'$blank'/' /var/www/include/config.php
sed -i 's/#cookie_domain/'$blank'/' /var/www/include/config.php
sed -i 's/#domain/'$blank'/' /var/www/include/config.php
sed -i 's/#announce_urls/'$announce'/' /var/www/include/config.php
sed -i 's/#announce_https/'$httpsannounce'/' /var/www/include/config.php
sed -i 's/#site_email/'$email'/' /var/www/include/config.php
sed -i 's/#site_name/'"$name"'/' /var/www/include/config.php
annconfigfile='/var/www/install/extra/ann_config.'$xbt'sample.php'
sed 's/#mysql_user/'$user'/' $annconfigfile > /var/www/include/ann_config.php
sed -i 's/#mysql_pass/'$pass'/' /var/www/include/ann_config.php
sed -i 's/#mysql_db/'$db'/' /var/www/include/ann_config.php
sed -i 's/#mysql_host/'$dbhost'/' /var/www/include/ann_config.php
sed -i 's/#baseurl/'$baseurl'/' /var/www/include/ann_config.php
sed -i 's/getStats()/getStats()["127.0.0.1:11211"]/' /var/www/templates/1/template.php
mysqlfile='/var/www/install/extra/install.'$xbt'.sql'
mysql -u $user -p$pass $db < $mysqlfile
mv /var/www/install /var/www/.install
if [[ -f /var/www/index.html ]]; then
	rm /var/www/index.html
fi
chown -R www-data:www-data /var/www
chown -R www-data:www-data /var/bucket

cd ~
if [ ! -f /etc/php/mods-available/memcached.ini ]; then
echo "; configuration for php memcached module
; priority=20
extension=memcached.so" > /etc/php/mods-available/memcached.ini
fi
if [ ! -f /etc/php/7.0/cli/conf.d/20-memcached.ini ]; then
ln -s /etc/php/mods-available/memcached.ini /etc/php/7.0/cli/conf.d/20-memcached.ini
fi
if [ ! -f /etc/php/7.0/fpm/conf.d/20-memcached.ini ] && [[ $webserver = 'nginx' ]]; then
ln -s /etc/php/mods-available/memcached.ini /etc/php/7.0/fpm/conf.d/20-memcached.ini
$STARTPHPFPM
fi
if [[ $webserver = 'apache2' ]] && [[ ! -f /etc/php/7.0/apache2/conf.d/20-memcached.ini ]]; then
	ln -s /etc/php/mods-available/memcached.ini /etc/php/7.0/apache2/conf.d/20-memcached.ini
fi
cd ~

if [[ $ssl = 'y' ]] && [[ $webserver = 'nginx' ]]; then
	apt-get install -y openssl
	mkdir -p /etc/nginx/ssl
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/$baseurl.key -out /etc/nginx/ssl/$baseurl.crt
	echo "server {
    listen   443;
    ssl on;
    ssl_certificate /etc/nginx/ssl/$baseurl.crt;
    ssl_certificate_key /etc/nginx/ssl/$baseurl.key;
    server_name $baseurl;
    root /var/www;
    index index.html index.htm index.php;

    server_name $baseurl;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php7.0-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location /pma {
        root /var;
        index index.php index.html index.htm;
        location ~ ^/pma/(.+\.php)$ {
            try_files \$uri =404;
            root /var;
            fastcgi_pass unix:/run/php/php7.0-fpm.sock;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include /etc/nginx/fastcgi_params;
        }

        location ~* ^/pma/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
            root /var;
        }
    }
}" > /etc/nginx/sites-available/$baseurl-ssl
ln -s /etc/nginx/sites-available/$baseurl-ssl /etc/nginx/sites-enabled
elif [[ $ssl = 'y' ]] && [[ $webserver = 'apache2' ]]; then
	apt-get install -y openssl
	mkdir -p /etc/apache2/ssl
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/apache2/ssl/$baseurl.key -out /etc/apache2/ssl/$baseurl.crt
	sed -i 's/\/var\/www\/html/\/var\/www/' /etc/apache2/sites-available/default-ssl.conf
	sed -i 's/\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/\/etc\/apache2\/ssl\/'$baseurl'.crt/' /etc/apache2/sites-available/default-ssl.conf
	sed -i 's/\/etc\/ssl\/private\/ssl-cert-snakeoil.key/\/etc\/apache2\/ssl\/'$baseurl'.key/' /etc/apache2/sites-available/default-ssl.conf
	chmod 600 /etc/apache2/ssl/*
	a2enmod ssl
	a2ensite default-ssl
fi

$STARTWEBSERVER

if [[ $xbt = 'xbt' ]]; then
    svn co -r 2466 http://xbt.googlecode.com/svn/trunk/xbt/misc xbt/misc
    svn co -r 2466 http://xbt.googlecode.com/svn/trunk/xbt/Tracker xbt/Tracker
    sleep 2
    cp -R /var/www/XBT/{server.cpp,server.h,xbt_tracker.conf}  /root/xbt/Tracker/
    cd /root/xbt/Tracker/
    ./make.sh
    sed -i 's/mysql_user=/mysql_user='$user'/' /root/xbt/Tracker/xbt_tracker.conf
    sed -i 's/mysql_password=/mysql_password='$pass'/' /root/xbt/Tracker/xbt_tracker.conf
    sed -i 's/mysql_database=/mysql_database='$db'/' /root/xbt/Tracker/xbt_tracker.conf
    sed -i 's/mysql_host=/mysql_host'$dbhost'/' /root/xbt/Tracker/xbt_tracker.conf
    cd /root/xbt/Tracker
    ./xbt_tracker
    cd /root/xbt/Tracker/ 
    SERVICE='xbt_tracker'
     if  ps ax | grep -v grep | grep $SERVICE > /dev/null
    then
        echo "$SERVICE service running, everything is fine"
    else
        echo "$SERVICE is not running, restarting $SERVICE"
        checkxbt="ps ax | grep -v grep | grep -c $SERVICE"
        if [ $checkxbt <= 0 ]
        then
        $STARTXBT
            if ps ax | grep -v grep | grep $SERVICE >/dev/null
        then
            echo "$SERVICE service is now restarted, everything is fine"
            fi
        fi
    fi
fi
######CHECK MEMCACHED######
SERVICE='memcached'

 if  ps ax | grep -v grep | grep $SERVICE > /dev/null
then
    echo "$SERVICE service running, everything is fine"
else
    echo "$SERVICE is not running, restarting $SERVICE" 
    chkmem="ps ax | grep -v grep | grep -c $SERVICE"
    if [ $chkmem <= 0 ]
    then
    $STARTMEMCACHED
        if ps ax | grep -v grep | grep $SERVICE >/dev/null
    then
        echo "$SERVICE service is now restarted, everything is fine"
        fi
    fi
fi
######CHECK nginx######
if [[ $webserver = 'nginx' ]]; then
	SERVICE='nginx'
fi
if [[ $webserver = 'apache2' ]]; then
	SERVICE='apache2'
fi

if  ps ax | grep -v grep | grep $SERVICE > /dev/null
then
    echo "$SERVICE service running, everything is fine"
else
    echo "$SERVICE is not running, restarting $SERVICE" 
    chkmem="ps ax | grep -v grep | grep -c $SERVICE"
    if [ $chkmem <= 0 ]
    then
    $STARTWEBSERVER
        if ps ax | grep -v grep | grep $SERVICE >/dev/null
    then
        echo "$SERVICE service is now restarted, everything is fine"
        fi
    fi
fi
if [[ $webserver = 'nginx' ]]; then
	######CHECK php-fpm######
	SERVICE='php-fpm'

	if  ps ax | grep -v grep | grep $SERVICE > /dev/null
	then
	    echo "$SERVICE service running, everything is fine"
	else
	    echo "$SERVICE is not running, restarting $SERVICE" 
	    chkmem="ps ax | grep -v grep | grep -c $SERVICE"
	    if [ $chkmem <= 0 ]
	    then
	    $STARTPHPFPM
	        if ps ax | grep -v grep | grep $SERVICE >/dev/null
	    then
	        echo "$SERVICE service is now restarted, everything is fine"
	        fi
	    fi
	fi
fi
echo "The site should now be accessable at http://$baseurl"
echo "phpMyAdmin is accessable at http://$baseurl/pma"
if [[ $ssl = 'y' ]]; then
	echo "Also at https://$baseurl and https://$baseurl/pma"
fi
