#!/bin/bash
if [[ $EUID != 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi
black=$(tput setaf 0); red=$(tput setaf 1); green=$(tput setaf 2); yellow=$(tput setaf 3);
blue=$(tput setaf 4); magenta=$(tput setaf 5); cyan=$(tput setaf 6); white=$(tput setaf 7);
on_red=$(tput setab 1); on_green=$(tput setab 2); on_yellow=$(tput setab 3); on_blue=$(tput setab 4);
on_magenta=$(tput setab 5); on_cyan=$(tput setab 6); on_white=$(tput setab 7); bold=$(tput bold);
dim=$(tput dim); underline=$(tput smul); reset_underline=$(tput rmul); standout=$(tput smso);
reset_standout=$(tput rmso); normal=$(tput sgr0); alert=${white}${on_red}; title=${standout};
sub_title=${bold}${yellow}; repo_title=${black}${on_green}; message_title=${white}${on_magenta}
OK=$(echo -e "[ ${bold}${green}DONE${normal} ]")
OUTTO='/dev/null'
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

function _depends() {
    apt-get -y update >>"${OUTTO}" 2>&1
    ##apt-get -y upgrade >>"${OUTTO}" 2>&1
    apt-get -y install lsb-release >>"${OUTTO}" 2>&1
}

spinner() {
    local pid=$1
    local delay=0.25
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [${bold}${yellow}%c${normal}]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    echo -ne "${OK}"
}


randomString;
pass=$myRandomResult
randomString;
pmakey=$(echo -n $myRandomResult | sha1sum | awk '{print $1}')
randomString;
mysqlroot=$myRandomResult
clear

echo 'This will install the absolute minimum requirements to get the site running'
echo -n "Enter the site's base url (with no http(s):// or www): "
read baseurl
echo -n "Enter the site's name: "
read name
echo -n "Enter the site's email: "
read email
echo -n "Do you want to enable SSL (y/n)
This will install a certificate from letsencrypt.org
This requires the domain(s) to be pointed to this server already: "
read ssl
if [[ $ssl = 'y' ]]; then
    echo -n "Do you need the certificate to include www.$baseurl (y/n): "
    read www
fi
echo -n "Do you want to install apache2 or nginx (apache2/nginx): "
read webserver
echo -n "Do you want to run XBT tracker or php? (xbt/php): "
read xbt
echo -n "Do you want to set your own mysql root password? (y/n): "
read sqlrootyn
case $sqlrootyn in
    'y' )
        echo -n "Enter the password you would like:"
        read -s mysqlroot2
        echo
        echo -n "Confirm the password:"
        read -s mysqlroot3
        echo
        if [[ $mysqlroot2 != $mysqlroot3 ]]; then
            echo -n "Those passwords did not match. Exiting installer"
            exit 1
        else
            mysqlroot=$mysqlroot2
        fi
    ;;
esac
announce=$announcebase$baseurl$announce2
httpsannounce=$httpsannouncebase$baseurl$announce2




echo -n "Installing First Dependancies ... ";_depends & spinner $!;echo
codename=$(lsb_release -cs)

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
if [[ $webserver = 'nginx' ]]; then
    STARTWEBSERVER='service nginx restart'
    STOPWEBSERVER='service nginx stop'
    webpackages='php7.0-fpm nginx'
elif [[ $webserver = 'apache2' ]]; then
    STARTWEBSERVER='service apache2 restart'
    STOPWEBSERVER='service apache2 stop'
    webpackages='libapache2-mod-php7.0 apache2'
fi

function _installsoftware() {
    apt-get -y install software-properties-common apt-transport-https >>"${OUTTO}" 2>&1
    apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db >>"${OUTTO}" 2>&1
    wget https://www.dotdeb.org/dotdeb.gpg >>"${OUTTO}" 2>&1
    apt-key add dotdeb.gpg >>"${OUTTO}" 2>&1
    wget https://packages.sury.org/php/apt.gpg >>"${OUTTO}" 2>&1
    apt-key add apt.gpg >>"${OUTTO}" 2>&1
    add-apt-repository "deb https://packages.sury.org/php/ jessie main"
    rm dotdeb.gpg apt.gpg
    add-apt-repository "deb http://packages.dotdeb.org jessie all" >>"${OUTTO}" 2>&1
    add-apt-repository "deb [arch=amd64,i386] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.1/debian jessie main" >>"${OUTTO}" 2>&1
    apt-get -y update >>"${OUTTO}" 2>&1
    export DEBIAN_FRONTEND=noninteractive
    echo mariadb-server-10.1 mariadb-server/root_password password $mysqlroot | debconf-set-selections
    echo mariadb-server-10.1 mariadb-server/root_password_again password $mysqlroot | debconf-set-selections
    echo mariadb-server-10.1 mysql-server/root_password password $mysqlroot | debconf-set-selections
    echo mariadb-server-10.1 mysql-server/root_password_again password $mysqlroot | debconf-set-selections
    apt-get -y purge exim4* >>"${OUTTO}" 2>&1
    apt-get -y install mariadb-server memcached unzip libssl-dev php7.0 php7.0-curl php7.0-igbinary php7.0-json php7.0-memcached php7.0-msgpack php-mbstring php7.0-gd php7.0-geoip php7.0-opcache php7.0-xml php7.0-zip php7.0-mcrypt php7.0-mysql sendmail sendmail-bin expect locate $webpackages $extras >>"${OUTTO}" 2>&1
    if [[ $ssl == 'y' ]]; then
        add-apt-repository "deb http://ftp.debian.org/debian jessie-backports main" >>"${OUTTO}" 2>&1
        apt-get -y update >>"${OUTTO}" 2>&1
        apt-get -y install python-certbot-apache certbot -t jessie-backports >>"${OUTTO}" 2>&1
    fi
}
function _securemysql() {
    SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \""$mysqlroot"\r\"
expect \"Change the root password?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
    ")
    
    echo "$SECURE_MYSQL" >>"${OUTTO}" 2>&1
}
echo -n "Installing Webserver and MariaDB ... ";_installsoftware & spinner $!;echo
echo -n "Securing MariaDB ... ";_securemysql & spinner $!;echo

updatedb

function _phpmyadmin() {
    cd ~
    wget https://files.phpmyadmin.net/phpMyAdmin/4.6.5.2/phpMyAdmin-4.6.5.2-english.tar.gz >>"${OUTTO}" 2>&1
    tar xfz phpMyAdmin-4.6.5.2-english.tar.gz
    rm phpMyAdmin-4.6.5.2-english.tar.gz
    mv phpMyAdmin-4.6.5.2-english /var/pma/
    cd /var/pma/
    cp config.sample.inc.php config.inc.php
    sed -i "s/\$cfg\["\'"blowfish_secret"\'"\] \= "\'\'"\;/\$cfg\["\'"blowfish_secret"\'"\] \= "\'""$pmakey""\'"\;/" config.inc.php
}
echo -n "Installing phpMyAdmin ... ";_phpmyadmin & spinner $!;echo
function _webconfig() {
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
    if [ ! -f /etc/php/7.0/mods-available/memcached.ini ]; then
        echo "; configuration for php memcached module
; priority=20
        extension=memcached.so" > /etc/php/7.0/mods-available/memcached.ini
    fi
    if [ ! -f /etc/php/7.0/cli/conf.d/20-memcached.ini ]; then
        ln -s /etc/php/7.0/mods-available/memcached.ini /etc/php/7.0/cli/conf.d/20-memcached.ini
    fi
    if [ ! -f /etc/php/7.0/fpm/conf.d/20-memcached.ini ] && [[ $webserver = 'nginx' ]]; then
        ln -s /etc/php/7.0/mods-available/memcached.ini /etc/php/7.0/fpm/conf.d/20-memcached.ini
        $STARTPHPFPM
    fi
    if [[ $webserver = 'apache2' ]] && [[ ! -f /etc/php/7.0/apache2/conf.d/20-memcached.ini ]]; then
        ln -s /etc/php/7.0/mods-available/memcached.ini /etc/php/7.0/apache2/conf.d/20-memcached.ini
    fi
    cd ~
    if [[ $ssl = 'y' ]]; then
        $STARTWEBSERVER
        if [[ $www = 'y' ]]; then
            certbot certonly --webroot -w /var/www -d $baseurl -w /var/www -d www.$baseurl -n --agree-tos --email $email --quiet >> ${OUTTO} 2>&1
        else
            certbot certonly --webroot -w /var/www -d $baseurl -n --agree-tos --email $email --quiet >> ${OUTTO} 2>&1
        fi
        if [[ -f /etc/letsencrypt/live/$baseurl/fullchain.pem ]]; then
            $ssl = 'n'
            cd ~
            echo "13 1 * * * certbot renew --renew-hook '/usr/sbin/$STARTWEBSERVER' --quiet" >> tempcron
            echo "13 13 * * * certbot renew --renew-hook '/usr/sbin/$STARTWEBSERVER' --quiet" >> tempcron
            crontab -u root tempcron
            rm tempcron
        fi
    fi
    if [[ $ssl = 'y' ]] && [[ $webserver = 'nginx' ]]; then
        apt-get install -y openssl >> ${OUTTO} 2>&1
        ##mkdir -p /etc/nginx/ssl
        ##openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/$baseurl.key -out /etc/nginx/ssl/$baseurl.crt -batch >> ${OUTTO} 2>&1
        echo "server {
    listen   443;
    ssl on;
    ssl_certificate /etc/letsencrypt/live/$baseurl/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$baseurl/privkey.pem;
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
        ##apt-get install -y openssl >> ${OUTTO} 2>&1
        ##mkdir -p /etc/apache2/ssl
        ##openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/apache2/ssl/$baseurl.key -out /etc/apache2/ssl/$baseurl.crt -batch >> ${OUTTO} 2>&1
        sed -i 's/\/var\/www\/html/\/var\/www/' /etc/apache2/sites-available/default-ssl.conf
        sed -i 's/\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/\/etc\/letsencrypt\/live\/'$baseurl'\/fullchain.pem/' /etc/apache2/sites-available/default-ssl.conf
        sed -i 's/\/etc\/ssl\/private\/ssl-cert-snakeoil.key/\/etc\/letsencrypt\/live\/'$baseurl'\/privkey.pem/' /etc/apache2/sites-available/default-ssl.conf
        ##chmod 600 /etc/apache2/ssl/*
        a2enmod ssl >> ${OUTTO} 2>&1
        a2ensite default-ssl >> ${OUTTO} 2>&1
        $STARTWEBSERVER
    fi
}
echo -n "Configuring the webserver ... ";_webconfig & spinner $!;echo
cd ~
echo "create database $db;
grant all on $db.* to '$user'@'localhost'identified by '$pass';" > blah.sql
mysql -u root -p$mysqlroot < blah.sql
rm blah.sql


function _v5files() {
    wget https://github.com/Bigjoos/U-232-V5/archive/master.tar.gz >> ${OUTTO} 2>&1
    tar xfz master.tar.gz
    cd U-232-V5-master
    tar xfz pic.tar.gz
    tar xfz GeoIP.tar.gz
    tar xfz Log_Viewer.tar.gz
    cd /var
    mkdir -p /var/bucket/avatar
    cd /var/bucket
    cp ~/U-232-V5-master/torrents/.htaccess .
    cp ~/U-232-V5-master/torrents/index.* .
    cd /var/bucket/avatar
    cp ~/U-232-V5-master/torrents/.htaccess .
    cp ~/U-232-V5-master/torrents/index.* .
    cd ~
    chmod -R 755 /var/bucket
    cp -ar ~/U-232-V5-master/* /var/www
    if [ ! -d /var/www/imdb/images ]; then
        mkdir /var/www/imdb/images
    fi
    if [ ! -d /var/www/imdb/cache ]; then
        mkdir /var/www/imdb/cache
    fi
    chmod -R 755 /var/www/cache
    chmod 755 /var/www/dir_list
    chmod 755 /var/www/uploads
    chmod 755 /var/www/uploadsub
    chmod 755 /var/www/imdb
    chmod 755 /var/www/imdb/cache
    chmod 755 /var/www/imdb/images
    chmod 755 /var/www/include
    chmod 755 /var/www/include/backup
    chmod 755 /var/www/include/settings
    echo > /var/www/include/settings/settings.txt
    chmod 755 /var/www/include/settings/settings.txt
    chmod 755 /var/www/sqlerr_logs/
    chmod 755 /var/www/torrents
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
    mysqlfile='/var/www/install/extra/install.'$xbt'.sql'
    mysql -u $user -p$pass $db < $mysqlfile
    mv /var/www/install /var/www/.install
    if [[ -f /var/www/index.html ]]; then
        rm /var/www/index.html
    fi
    chown -R www-data:www-data /var/www
    chown -R www-data:www-data /var/bucket
}
echo -n "Installing U-232 V5 ... ";_v5files & spinner $!;echo


$STARTWEBSERVER
function _xbtinstall() {
    cd /root
    wget https://github.com/whocares-openscene/u-232-xbt/raw/master/xbt.tar.gz >> ${OUTTO} 2>&1
    tar xfz xbt.tar.gz
    cd /root/xbt/Tracker/
    ./make.sh
    sed -i 's/mysql_user=/mysql_user='$user'/' /root/xbt/Tracker/xbt_tracker.conf
    sed -i 's/mysql_password=/mysql_password='$pass'/' /root/xbt/Tracker/xbt_tracker.conf
    sed -i 's/mysql_database=/mysql_database='$db'/' /root/xbt/Tracker/xbt_tracker.conf
    sed -i 's/mysql_host=/mysql_host'$dbhost'/' /root/xbt/Tracker/xbt_tracker.conf
    cd /root/xbt/Tracker
    ./xbt_tracker
}
if [[ $xbt = 'xbt' ]]; then
    echo -n "Installing XBT ... ";_xbtinstall & spinner $!;echo
    SERVICE='xbt_tracker'
    if  ps ax | grep -v grep | grep $SERVICE > /dev/null
    then
        echo "$SERVICE service running, everything is fine"
    else
        echo "$SERVICE is not running, restarting $SERVICE"
        checkxbt="ps ax | grep -v grep | grep -c $SERVICE"
        if [ $checkxbt <= 0 ]
        then
            cd /root/xbt/Tracker
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
echo "The site should now be accessable at http://$baseurl" >> ./serverinfo.log 2>&1
echo "phpMyAdmin is accessable at http://$baseurl/pma" >> ./serverinfo.log 2>&1
if [[ $ssl = 'y' ]]; then
    if [[ -f /etc/letsencrypt/live/$baseurl/fullchain.pem ]]; then
        echo "Installation of the SSL certificate failed."
        echo "Check out the letsencrypt error logs in /var/log/letsencrypt/"
    else
        echo "Also at https://$baseurl and https://$baseurl/pma"
        echo "Also at https://$baseurl and https://$baseurl/pma" >> ./serverinfo.log 2>&1
		fi
fi
echo "Your root mysql password is $mysqlroot"
echo "Your root mysql password is $mysqlroot" >> ./serverinfo.log 2>&1