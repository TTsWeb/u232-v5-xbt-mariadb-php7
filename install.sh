#!/bin/bash
if [[ $EUID != 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi
STARTAPACHE='/etc/init.d/apache2 restart'
STARTXBT='./xbt_tracker'
STARTMEMCACHED='/etc/init.d/memcached restart'
user='u232'
db='u232'
dbhost='localhost'
blank=''
announcebase='http:\/\/'
httpsannouncebase='https:\/\/'
announce2='\/announce.php'
xbt='xbt'
codename=$(lsb_release -a | grep Codename | awk '{ printf $2 }')
function randomString {
        local myStrLength=16;
        local mySeedNumber=$$`date +%N`;
        local myRandomString=$( echo $mySeedNumber | md5sum | md5sum );
        myRandomResult="${myRandomString:2:myStrLength}"
}

randomString;
pass=$myRandomResult
clear

echo 'This will install the absolute minimum requirements to get the site running'
echo -n "Enter the site's base url (with no http(s):// or www): "
read baseurl
echo -n "Enter the site's name: "
read name
echo -n "Enter the site's email: "
read email
announce=$announcebase$baseurl$announce2
httpsannounce=$httpsannouncebase$baseurl$announce2
apt-get -y update
apt-get -y upgrade

case $codename in
	"jessie" | "wheezy") ## Debian Flavors (can do xbt)
        software='software-properties-common'
        repository="deb [arch=amd64,i386] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.1/debian $codename main"
        ;;
    "trusty" | "vivid" | "saucy") ## Ubuntu Flavors (can do xbt)
        software='software-properties-common'
        repository="deb [arch=amd64,i386] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.1/ubuntu $codename main"
        ;;
    "wily") ## Ubuntu Wily (Mariadb does not have specific repository yet)
        software='software-properties-common'
        repository="deb [arch=amd64,i386] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.1/ubuntu vivid main"
        ;;
    "squeeze") ## Debian Squeeze (cannot handle xbt, needs to make its own file for repository)
        software=''
        repository=''
        echo "# MariaDB 10.1 repository list - created 2014-11-21 00:35 UTC # http://mariadb.org/mariadb/repositories/
        deb [arch=amd64,i386] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.1/debian squeeze main
        deb-src http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.1/debian squeeze main" > /etc/apt/sources.list.d/mariadb.list
        xbt='php'
        echo -n "You are running Debian 6, this script is not able to install XBT tracker is this ok? (y/n)"
        read xbtyn
        ;;
    "precise" | "lucid") ## Ubuntu Flavors (cannot do xbt)
        software='python-software-properties'
        repository="deb [arch=amd64,i386] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.1/ubuntu $codename main"
        xbt='php'
        echo -n "You are running Ubuntu 10 or 12, this script is not able to install XBT tracker is this ok? (y/n)"
        read xbtyn
        ;;
    *)
        echo `tput setaf 1``tput bold`"This OS is not yet supported! (EXITING)"`tput sgr0`
        echo
        exit 1
        ;;
esac
if [[ $xbtyn = 'n' ]]; then
    exit 1
fi
if [[ $xbt = 'xbt' ]]; then
    echo -n "Do you want to run XBT tracker or php? (xbt/php)"
    read xbt
fi
case $xbt in
    'xbt')
        ;;
    'php')
        ;;
    *)
        echo`tput setaf 1``tput bold`"You did not enter a valid tracker type (EXITING)"`tput sgr0`
        echo
        exit 1
        ;;
esac
apt-get -y install $software
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
if [[ $codename != "squeeze" ]]; then
	add-apt-repository "$repository"
fi

apt-get -y update
apt-get -y install mariadb-server apache2 memcached unzip libssl-dev php5 libapache2-mod-php5 php5-mysql php5-memcache php5-json locate
apt-get -y install phpmyadmin

if [[ $xbt = 'xbt' ]]; then
    announce=$announcebase$baseurl
    apt-get -y install libmariadbclient-dev libpcre3 libpcre3-dev cmake g++ libboost-date-time-dev libboost-dev libboost-filesystem-dev libboost-program-options-dev libboost-regex-dev libboost-serialization-dev make subversion zlib1g-dev 
fi
updatedb
mysql_secure_installation
cd /etc/apache2/sites-enabled
sed -i 's/\/var\/www\/html/\/var\/www/' 000-default*
$STARTAPACHE
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
rm /var/www/index.html
chown -R www-data:www-data /var/www
chown -R www-data:www-data /var/bucket

cd ~
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

         checkxbt=`ps ax | grep -v grep | grep -c xbt_tracker`

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

     chkmem=`ps ax | grep -v grep | grep -c memcached`

     if [ $chkmem <= 0 ]

    then 

    $STARTMEMCACHED

        if ps ax | grep -v grep | grep $SERVICE >/dev/null

    then

        echo "$SERVICE service is now restarted, everything is fine"

        fi

    fi
        
fi

#####CHECK APACHE2###########
SERVICE='apache2'

if ps ax | grep -v grep | grep $SERVICE > /dev/null

then

    echo "$SERVICE service running, everything is fine" 

else

    echo "$SERVICE is not running, restarting $SERVICE" 

        checkapache=`ps ax | grep -v grep | grep -c apache2`

                if [ $checkapache <= 0 ]

                then

                        $STARTAPACHE

                                if ps ax | grep -v grep | grep $SERVICE > /dev/null

                then

                            echo "$SERVICE service is now restarted, everything is fine" 

                                fi

                fi

fi
