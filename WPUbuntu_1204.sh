#!/bin/bash
# -----------------------------------------------------------------------
# First we check if the user is 'root' before allowing installation to commence
# -----------------------------------------------------------------------
if [ $UID -ne 0 ]; then
    echo "# Install failed! You must be logged in as 'root', please try again."
	echo "# -----------------------------------------------------------------------"
    exit 1
fi
echo "# Are you ready to install?"
echo "# -----------------------------------------------------------------------"
read -p "Y or N? : " init
if [[ $init == [Yy] ]] ; then
apt-get update -qq && apt-get -y dist-upgrade
# Lets check for some common control panels that we know will affect the installation/operating of WPUbuntu.
if [ -e /usr/local/cpanel ] || [ -e /usr/local/directadmin ] || [ -e /usr/local/solusvm/www ] || [ -e /usr/local/home/admispconfig ] || [ -e /usr/local/lxlabs/kloxo ] ; then
    echo "# -----------------------------------------------------------------------"
    echo "You appear to have a control panel already installed on your server!"
    echo "Please re-install your OS before attempting to install using this script."
    echo "# -----------------------------------------------------------------------"
    echo "Press any key to exit..."
    read exit
    exit
fi
if dpkg -s php apache mysql bind; then
    echo "# -----------------------------------------------------------------------"
    echo "You appear to have a server with LAMP already installed!"
    echo "Please re-install your OS before attempting to install using this script."
    echo "# -----------------------------------------------------------------------"
    echo "Press any key to exit..."
    read exit
    exit
fi
# -----------------------------------------------------------------------
# Ensure the installer is launched and can only be launched on Ubuntu 12.04
# -----------------------------------------------------------------------
BITS=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
if [ -f /etc/lsb-release ]; then
  OS=$(cat /etc/lsb-release | grep DISTRIB_ID | sed 's/^.*=//')
  VER=$(cat /etc/lsb-release | grep DISTRIB_RELEASE | sed 's/^.*=//')
else
  OS=$(uname -s)
  VER=$(uname -r)
fi
echo "Detected : $OS  $VER  $BITS"
if [ "$OS" = "Ubuntu" ] && [ "$VER" = "12.04" ]; then
  echo "Ok."
else
  echo "# -----------------------------------------------------------------------"
  echo "Sorry, this installer only supports WPU on Ubuntu 12.04."
  echo "# -----------------------------------------------------------------------"
  exit 1;
fi
# -----------------------------------------------------------------------
# Display the 'welcome' splash/user warning info..
# -----------------------------------------------------------------------
echo -e ""
echo "# ======================================================================="
echo "#"
echo "#             I n s t a l l   W P U b u n t u   1 2 . 0 4"
echo "#"
echo "# ======================================================================="
# -----------------------------------------------------------------------
# Set some installation defaults/auto assignments
# -----------------------------------------------------------------------
fqdn=`/bin/hostname`
publicip=`wget -qO- http://api.zpanelcp.com/ip.txt`
# Lets check that the user wants to continue first as obviously otherwise we'll be removing AppArmor for no reason.
while true; do
read -e -p "Would you like to continue (y/n)? " yn
    case $yn in
		[Yy]* ) break;;
		[Nn]* ) exit;
	esac
done
# -----------------------------------------------------------------------
# Generates random passwords for the 'zadmin' account as well as Postfix and MySQL root account.
# -----------------------------------------------------------------------
passwordgen() {
    	 l=$1
           [ "$l" == "" ] && l=16
          tr -dc A-Za-z0-9 < /dev/urandom | head -c ${l} | xargs
}
apt-get -qqy install sudo wget vim nano make zip unzip git preload
mkdir /wpu && cd /
git clone https://github.com/WPUbuntu/WPU.git /wpu
cd /wpu
git checkout stable
chmod 777 * && chown root:root *
ln init.d/wpu /etc/init.d/wpu
chmod 755 /etc/init.d/wpu && chown root:root /etc/init.d/wpu
sudo update-rc.d wpu defaults
sudo update-rc.d wpu enable
apt-get install -qqy lamp-server^ proftpd
# Generation of random passwords
sqlpassword=`passwordgen`;
ftppassword=`passwordgen`;
chmod -R 770 /wpu/www/
chown -R www-data:www-data /wpu/www/
service mysql start
mysqladmin -u root password "$password"
until mysql -u root -p$sqlpassword -e ";" > /dev/null 2>&1 ; do
read -s -p "enter your root mysql password : " password
done
sed -i "s|YOUR_ROOT_MYSQL_PASSWORD|$password|" /etc/zpanel/panel/cnf/db.php
mysql -u root -p$sqlpassword -e "DROP DATABASE test";
mysql -u root -p$sqlpassword -e "DELETE FROM mysql.user WHERE User='root' AND Host != 'localhost'";
mysql -u root -p$sqlpassword -e "DELETE FROM mysql.user WHERE User=''";
mysql -u root -p$sqlpassword -e "FLUSH PRIVILEGES";
echo "NameVirtualHost *:80" >> /etc/apache2/httpd.conf
mv /etc/apache2/sites-available/default /etc/apache2/sites-available/backup
touch /etc/apache2/sites-available/default
echo "<VirtualHost *:80>" >> /etc/apache2/sites-available/default
echo "   DocumentRoot /wpu/www/ip" >> /etc/apache2/sites-available/default
echo "   <Directory />" >> /etc/apache2/sites-available/default
echo "      Option FallowSymLinks" >> /etc/apache2/sites-available/default
echo "      AllowOverride None" >> /etc/apache2/sites-available/default
echo "   </Directory>" >> /etc/apache2/sites-available/default
echo "   <Directory /wpu/www/ip/" >> /etc/apache2/sites-available/default
echo "      Options Indexes FallowSymLinks MultiViews" >> /etc/apache2/sites-available/default
echo "      AllowOverride None" >> /etc/apache2/sites-available/default
echo "      Order allow,deny" >> /etc/apache2/sites-available/default
echo "      allow from all" >> /etc/apache2/sites-available/default
echo "   </Directory>" >> /etc/apache2/sites-available/default
echo "   ScriptAlias /cgi-bin/ /user/lib/cgi-bin/" >> /etc/apache2/sites-available/default
echo "   <Directory "/usr/lib/cgi-bin/">" >> /etc/apache2/sites-available/default
echo "      AllowOverride None" >> /etc/apache2/sites-available/default
echo "      Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch" >> /etc/apache2/sites-available/default
echo "      Order allow,deny" >> /etc/apache2/sites-available/default
echo "      allow from all" >> /etc/apache2/sites-available/default
echo "   </Directory>" >> /etc/apache2/sites-available/default
echo "   ErrorLog ${APACHE_LOG_DIR}/error.log" >> /etc/apache2/sites-available/default
echo "   LogLevel warning" >> /etc/apache2/sites-available/default
echo "   CustomLog ${APACHE_LOG_DIR}/access.log combined" >> /etc/apache2/sites-available/default
echo "   Alias /doc/ "/usr/share/doc/"" >> /etc/apache2/sites-available/default
echo "   <Directory "/usr/share/doc/">" >> /etc/apache2/sites-available/default
echo "      Options Indexes MultiViews FollowSymLinks" >> /etc/apache2/sites-available/default
echo "      AllowOverride None" >> /etc/apache2/sites-available/default
echo "      Order deny,allow" >> /etc/apache2/sites-available/default
echo "      Deny from all" >> /etc/apache2/sites-available/default
echo "      Allow from 127.0.0.0/255.0.0.0 ::1/128" >> /etc/apache2/sites-available/default
echo "   </Directory>" >> /etc/apache2/sites-available/default
echo "</VirtualHost>" >> /etc/apache2/sites-available/default
sudo a2enmod rewrite
sudo adduser --disabled-login --gecos 'WPUbuntu' wpu -p $ftppassword -d /wpu/www -s /bin/false
# We'll store the passwords so that users can review them later if required.
touch /root/wpu_info.txt;
echo "MySQL Root Password: $password" >> /root/wpu_info.txt
echo "IP Address: $publicip" >> /root/wpu_info.txt
echo "Panel Domain: $fqdn" >> /root/wpu_info.txt
touch /wpu/log/log
DATE=$(date)
HOST=$(hostname)
echo "# =======================================================================" >> /wpu/log/log
echo "WPUbuntu install was SUCCESSFUL on $DATE." >> /wpu/log/log
echo "# -----------------------------------------------------------------------" >> /wpu/log/log
echo "Host: $HOSTNAME" >> /wpu/log/
echo "IP: $publicip" >> /wpu/log/log
echo "FTP Username: wpu" >> /wpu/log/log
echo "IP: $ftppassword" >> /wpu/log/log
echo "# =======================================================================" >> /wpu/log/log
service apache2 reload
service mysql reload
service proftpd restart
echo -e "# -----------------------------------------------------------------------" &>/dev/tty
echo -e "#"
echo -e "# Save the following information or goto /root/wpu_info.txt:" &>/dev/tty
echo -e "# MySQL Root Password    : $password" &>/dev/tty
echo -e "# Default FTP Username   : wpu" &>/dev/tty
echo -e "# Default FTP Password   : $ftppassword" &>/dev/tty
echo -e "#" &>/dev/tty
echo -e "# -----------------------------------------------------------------------" &>/dev/tty
echo -e "" &>/dev/tty

# We now request that the user restarts their server...
read -e -p "Restart your server now to complete the install (y/n)? " rsn
while true; do
	case $rsn in
		[Yy]* ) break;;
		[Nn]* ) exit;
	esac
done
fi
if [[ $init == [Nn] ]] ; then
exit;
fi
reboot
