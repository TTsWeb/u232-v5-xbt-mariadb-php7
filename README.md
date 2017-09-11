This is for Debian 8-9, there is other script maybe for other OS's but you will need to have the brain power to fix them.

# u232-v5-xbt-mariadb-php7
This is a mess of different scripts found to install U-232 V5 on Debian 8-9

u232-v5-deb9.sh    = Debian 9
u232-v5.sh         = Debian 8
ocelot_installs.sh = Install things need for ocelot, eggdrops, misc things needed to run the site for Debian 9 Only.

Only ones I know work is
https://github.com/TTsWeb/u232-v5-xbt-mariadb-php7/blob/master/u232-v5-deb9.sh or https://github.com/TTsWeb/u232-v5-xbt-mariadb-php7/blob/master/u232-v5.sh

Other ones are there incase people got the brain power to fix them from there system and are NOT supported via ME and support issues for the none main scripts will be deleted!

XBT is gone from svn so you will need to find another source for it. This seems to work for NOW.
cd /root
wget https://github.com/TTsWeb/u232-v5-xbt-mariadb-php7/raw/master/xbt.tar.gz
tar xfz xbt.tar.gz
cd /root/xbt/Tracker/
./make.sh
