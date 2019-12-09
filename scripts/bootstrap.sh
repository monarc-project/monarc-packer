#! /usr/bin/env bash

# Variables
MonarcAppFO_Git_Repo='https://github.com/monarc-project/MonarcAppFO.git'
PATH_TO_MONARC='/var/lib/monarc/fo'

ENVIRONMENT='production'

# Database configuration
DBHOST='localhost'
DBNAME_COMMON='monarc_common'
DBNAME_CLI='monarc_cli'
DBUSER_ADMIN='root'
DBPASSWORD_ADMIN="$(openssl rand -hex 32)"
DBUSER_MONARC='sqlmonarcuser'
DBPASSWORD_MONARC="$(openssl rand -hex 32)"

# Timing creation
TIME_START=$(date +%s)

# php.ini configuration
upload_max_filesize=200M
post_max_size=50M
max_execution_time=100
max_input_time=223
memory_limit=512M
PHP_INI=/etc/php/7.2/apache2/php.ini

export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
dpkg-reconfigure locales

echo "--- Installing MONARC FO… ---"

echo "--- Updating packages list… ---"
sudo apt-get update
sudo apt-get -y upgrade


echo "--- Install base packages… ---"
sudo apt-get -y install vim zip unzip git gettext curl  > /dev/null


echo "--- Install MariaDB specific packages and settings… ---"
# echo "mysql-server mysql-server/root_password password $DBPASSWORD_ADMIN" | sudo debconf-set-selections
# echo "mysql-server mysql-server/root_password_again password $DBPASSWORD_ADMIN" | sudo debconf-set-selections
sudo apt-get -y install mariadb-server > /dev/null
# Secure the MariaDB installation (especially by setting a strong root password)
sudo systemctl restart mariadb.service > /dev/null
sleep 5
sudo apt-get -y install expect > /dev/null
## do we need to spawn mysql_secure_install with sudo in future?
expect -f - <<-EOF
set timeout 10
spawn mysql_secure_installation
expect "Enter current password for root (enter for none):"
send -- "\r"
expect "Set root password?"
send -- "y\r"
expect "New password:"
send -- "${DBPASSWORD_ADMIN}\r"
expect "Re-enter new password:"
send -- "${DBPASSWORD_ADMIN}\r"
expect "Remove anonymous users?"
send -- "y\r"
expect "Disallow root login remotely?"
send -- "y\r"
expect "Remove test database and access to it?"
send -- "y\r"
expect "Reload privilege tables now?"
send -- "y\r"
expect eof
EOF
sudo apt-get purge -y expect > /dev/null 2>&1


echo "--- Installing PHP-specific packages… ---"
sudo apt-get -y install php apache2 libapache2-mod-php php-curl php-gd php-mysql php-pear php-apcu php-xml php-mbstring php-intl php-imagick php-zip composer > /dev/null


echo "--- Configuring PHP ---"
for key in upload_max_filesize post_max_size max_execution_time max_input_time memory_limit
do
 sudo sed -i "s/^\($key\).*/\1 = $(eval echo \${$key})/" $PHP_INI
done


echo "--- Enabling mod-rewrite and ssl… ---"
sudo a2enmod rewrite > /dev/null
sudo a2enmod ssl > /dev/null
sudo a2enmod headers > /dev/null


echo "--- Allowing Apache override to all ---"
sudo sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf


echo "--- Setting up our MySQL user for MONARC… ---"
sudo mysql -u root -p$DBPASSWORD_ADMIN -e "CREATE USER '$DBUSER_MONARC'@'localhost' IDENTIFIED BY '$DBPASSWORD_MONARC';"
sudo mysql -u root -p$DBPASSWORD_ADMIN -e "GRANT ALL PRIVILEGES ON * . * TO '$DBUSER_MONARC'@'localhost';"
sudo mysql -u root -p$DBPASSWORD_ADMIN -e "FLUSH PRIVILEGES;"


echo "--- Retrieving MONARC… ---"
sudo mkdir -p $PATH_TO_MONARC
sudo chown monarc:monarc $PATH_TO_MONARC
sudo -u monarc git clone --config core.filemode=false $MonarcAppFO_Git_Repo $PATH_TO_MONARC
if [ $? -ne 0 ]; then
    echo "ERROR: unable to clone the MOMARC repository"
    exit 1;
fi
cd $PATH_TO_MONARC


echo "--- Installing MONARC core modules… ---"
sudo -u monarc composer install -o

# Modules
sudo -u monarc mkdir -p module/Monarc
cd module/Monarc
sudo -u monarc ln -s ./../../vendor/monarc/core Core
sudo -u monarc ln -s ./../../vendor/monarc/frontoffice FrontOffice

# Interfaces
cd $PATH_TO_MONARC
sudo -u monarc mkdir node_modules
cd node_modules
sudo -u monarc git clone --config core.filemode=false https://github.com/monarc-project/ng-client.git ng_client > /dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: unable to clone the ng-client repository"
    exit 1;
fi
sudo -u monarc git clone --config core.filemode=false https://github.com/monarc-project/ng-anr.git ng_anr > /dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: unable to clone the ng-anr repository"
    exit 1;
fi


echo "--- Add a VirtualHost for MONARC… ---"
sudo bash -c "cat > /etc/apache2/sites-enabled/000-default.conf <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot $PATH_TO_MONARC/public

    <Directory $PATH_TO_MONARC/public>
        DirectoryIndex index.php
        AllowOverride All
        Require all granted
    </Directory>

    <IfModule mod_headers.c>
       Header always set X-Content-Type-Options nosniff
       Header always set X-XSS-Protection '1; mode=block'
       Header always set X-Robots-Tag none
       Header always set X-Frame-Options SAMEORIGIN
    </IfModule>

    SetEnv APPLICATION_ENV $ENVIRONMENT
</VirtualHost>
EOF"


echo "--- Configuration of MONARC data base connection… ---"
cd $PATH_TO_MONARC
sudo -u monarc cat > config/autoload/local.php <<EOF
<?php
\$package_json = json_decode(file_get_contents('./package.json'), true);

return array(
    'doctrine' => array(
        'connection' => array(
            'orm_default' => array(
                'params' => array(
                    'host' => '$DBHOST',
                    'user' => '$DBUSER_MONARC',
                    'password' => '$DBPASSWORD_MONARC',
                    'dbname' => '$DBNAME_COMMON',
                ),
            ),
            'orm_cli' => array(
                'params' => array(
                    'host' => '$DBHOST',
                    'user' => '$DBUSER_MONARC',
                    'password' => '$DBPASSWORD_MONARC',
                    'dbname' => '$DBNAME_CLI',
                    ),
                ),
            ),
        ),

    /* Link with (ModuleCore)
    config['languages'] = [
        'fr' => array(
            'index' => 1,
            'label' => 'Français'
        ),
        'en' => array(
            'index' => 2,
            'label' => 'English'
        ),
        'de' => array(
            'index' => 3,
            'label' => 'Deutsch'
        ),
    ]
    */
    'activeLanguages' => array('fr','en','de','nl',),

    'appVersion' => \$package_json['version'],

    'checkVersion' => true,
    'appCheckingURL' => 'https://version.monarc.lu/check/MONARC',

    'email' => [
            'name' => 'MONARC',
            'from' => 'info@monarc.lu',
    ],

    'monarc' => array(
        'ttl' => 60, // timeout
        'salt' => '', // private salt for password
    ),
);
EOF

sudo mkdir -p $PATH_TO_MONARC/data/cache
sudo mkdir -p $PATH_TO_MONARC/data/LazyServices/Proxy
sudo mkdir -p $PATH_TO_MONARC/data/DoctrineORMModule/Proxy
sudo chown -R www-data data
sudo chmod -R 777 data


echo "--- Creation of the data bases… ---"
mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC -e "CREATE DATABASE monarc_cli DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;" > /dev/null
mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC -e "CREATE DATABASE monarc_common DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;" > /dev/null
echo "--- Populating MONARC DB… ---"
sudo -u monarc mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC monarc_common < db-bootstrap/monarc_structure.sql > /dev/null
sudo -u monarc mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC monarc_common < db-bootstrap/monarc_data.sql > /dev/null


echo "--- Installation Node, NPM and Grunt… ---"
curl -sL https://deb.nodesource.com/setup_13.x | sudo bash -
sudo apt-get install -y nodejs
sudo npm install -g grunt-cli


echo "--- Update the project… ---"
sudo -u monarc ./scripts/update-all.sh


echo "--- Create initial user and client ---"
sudo -u www-data php ./vendor/robmorgan/phinx/bin/phinx seed:run -c ./module/Monarc/FrontOffice/migrations/phinx.php


echo "--- Restarting Apache… ---"
sudo systemctl restart apache2.service > /dev/null

TIME_END=$(date +%s)
TIME_DELTA=$(expr ${TIME_END} - ${TIME_START})


echo "--- MONARC is ready! ---"
echo "Login and passwords for the MONARC image are the following:"
echo "MONARC application: admin@admin.localhost:admin"
echo "SSH login: monarc:password"
echo "Mysql root login: $DBUSER_ADMIN:$DBPASSWORD_ADMIN"
echo "Mysql MONARC login: $DBUSER_MONARC:$DBPASSWORD_MONARC"


echo "The generation took ${TIME_DELTA} seconds"
