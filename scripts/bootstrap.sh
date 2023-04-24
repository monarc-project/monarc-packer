#! /usr/bin/env bash

# Variables
PATH_TO_MONARC='/var/lib/monarc/fo'
PATH_TO_MONARC_DATA='/var/lib/monarc/fo-data'

ENVIRONMENT='production'

# Database configuration
DBHOST='localhost'
DBNAME_COMMON='monarc_common'
DBNAME_CLI='monarc_cli'
DBUSER_ADMIN='root'
DBPASSWORD_ADMIN="a7daab4243ed998c7e61dc6e4aa48f64dda354021778379ec11e75430534693e"
DBUSER_MONARC='sqlmonarcuser'
DBPASSWORD_MONARC="8c125ed24f4cf1fe50ec8ac4450c81c98b65475677956242bb9385e97fa4027d"


# Stats service
STATS_PATH='/home/monarc/stats-service'
STATS_PORT='5000'
STATS_SECRET_KEY="c3ff95aa569afa36f5395317fb77dc300507fe3c"


# Timing creation
TIME_START=$(date +%s)

# php.ini configuration
upload_max_filesize=200M
post_max_size=200M
max_execution_time=200
max_input_time=223
memory_limit=1024M

PHP_INI=/etc/php/8.1/apache2/php.ini

MARIA_DB_CFG=/etc/mysql/mariadb.conf.d/50-server.cnf

export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
sudo -E locale-gen en_US.UTF-8
sudo -E dpkg-reconfigure locales


# set -e


echo -e "--- Installing MONARC FO… ---"

echo -e "--- Updating packages list… ---"
sudo apt-get update && sudo apt-get upgrade -y

echo -e "--- Install base packages… ---"
sudo apt-get -y install vim zip unzip git gettext curl gsfonts jq > /dev/null

MONARC_VERSION=$(curl --silent -H 'Content-Type: application/json' https://api.github.com/repos/monarc-project/MonarcAppFO/releases/latest | jq  -r '.tag_name')
MONARCFO_RELEASE_URL="https://github.com/monarc-project/MonarcAppFO/releases/download/$MONARC_VERSION/MonarcAppFO-$MONARC_VERSION.tar.gz"
MONARC_VERSION_NUMERIC=$(echo $MONARC_VERSION | sed -E "s/^v?([0-9\.]+).*$/\1/")

echo -e "--- Install MariaDB specific packages and settings… ---"
# echo "mysql-server mysql-server/root_password password $DBPASSWORD_ADMIN" | sudo debconf-set-selections
# echo "mysql-server mysql-server/root_password_again password $DBPASSWORD_ADMIN" | sudo debconf-set-selections
sudo apt -y install mariadb-server mariadb-client > /dev/null

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

echo -e "\n--- Configuring… ---\n"
sudo sed -i "s/skip-external-locking/#skip-external-locking/g" $MARIA_DB_CFG
sudo sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" $MARIA_DB_CFG
sudo sed -i "s/.*character-set-server.*/character-set-server = utf8mb4/" $MARIA_DB_CFG
sudo sed -i "s/.*collation-server.*/collation-server = utf8mb4_general_ci/" $MARIA_DB_CFG


echo -e "--- Installing PHP-specific packages… ---"
sudo apt-get install -y php8.1 php8.1-cli php8.1-common php8.1-mysql php8.1-zip php8.1-gd php8.1-mbstring php8.1-curl php8.1-xml php8.1-bcmath php8.1-intl php8.1-imagic > /dev/null



echo -e "--- Configuring PHP ---"
for key in upload_max_filesize post_max_size max_execution_time max_input_time memory_limit
do
 sudo sed -i "s/^\($key\).*/\1 = $(eval echo \${$key})/" $PHP_INI
done
# session expires in 1 week:
sudo sed -i "s/^\(session\.gc_maxlifetime\).*/\1 = $(eval echo 604800)/" $PHP_INI
sudo sed -i "s/^\(session\.gc_probability\).*/\1 = $(eval echo 1)/" $PHP_INI
sudo sed -i "s/^\(session\.gc_divisor\).*/\1 = $(eval echo 1000)/" $PHP_INI


echo -e "--- Enabling mod-rewrite and ssl… ---"
sudo a2enmod rewrite > /dev/null
sudo a2enmod ssl > /dev/null
sudo a2enmod headers > /dev/null


echo -e "--- Allowing Apache override to all ---"
sudo sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf


echo -e "--- Setting up our MySQL user for MONARC… ---"
sudo mysql -u root -p$DBPASSWORD_ADMIN -e "CREATE USER '$DBUSER_MONARC'@'localhost' IDENTIFIED BY '$DBPASSWORD_MONARC';"
sudo mysql -u root -p$DBPASSWORD_ADMIN -e "GRANT ALL PRIVILEGES ON * . * TO '$DBUSER_MONARC'@'localhost';"
sudo mysql -u root -p$DBPASSWORD_ADMIN -e "FLUSH PRIVILEGES;"


echo -e "--- Retrieving and installing MONARC… ---"
sudo mkdir -p /var/lib/monarc/releases/
# Download release
sudo curl -sL $MONARCFO_RELEASE_URL -o /var/lib/monarc/releases/`basename $MONARCFO_RELEASE_URL`
# Create release directory
sudo mkdir /var/lib/monarc/releases/`basename $MONARCFO_RELEASE_URL | sed 's/.tar.gz//'`
# Unarchive release
sudo tar -xzf /var/lib/monarc/releases/`basename $MONARCFO_RELEASE_URL` -C /var/lib/monarc/releases/`basename $MONARCFO_RELEASE_URL | sed 's/.tar.gz//'`
# Create release symlink
sudo ln -s /var/lib/monarc/releases/`basename $MONARCFO_RELEASE_URL | sed 's/.tar.gz//'` $PATH_TO_MONARC
# Create data and caches directories
sudo mkdir -p $PATH_TO_MONARC_DATA/cache $PATH_TO_MONARC_DATA/DoctrineORMModule/Proxy $PATH_TO_MONARC_DATA/LazyServices/Proxy $PATH_TO_MONARC_DATA/data/import/files
# Create data directory symlink
sudo ln -s $PATH_TO_MONARC_DATA $PATH_TO_MONARC/data
sudo chown -R www-data:www-data /var/lib/monarc/


echo -e "--- Configuration of MONARC data base connection… ---"
cd $PATH_TO_MONARC
sudo -u www-data bash -c "cat << EOF > config/autoload/local.php
<?php
return [
    'doctrine' => [
        'connection' => [
            'orm_default' => [
                'params' => [
                    'host' => '$DBHOST',
                    'user' => '$DBUSER_MONARC',
                    'password' => '$DBPASSWORD_MONARC',
                    'dbname' => '$DBNAME_COMMON',
                ],
            ],
            'orm_cli' => [
                'params' => [
                    'host' => '$DBHOST',
                    'user' => '$DBUSER_MONARC',
                    'password' => '$DBPASSWORD_MONARC',
                    'dbname' => '$DBNAME_CLI',
                ],
            ],
        ],
    ],

    'activeLanguages' => ['fr','en','de','nl','es','it','ja','pl','pt','ru','zh'],

    'appVersion' => '$MONARC_VERSION_NUMERIC',

    'checkVersion' => false,
    'appCheckingURL' => 'https://version.monarc.lu/check/MONARC',

    'instanceName' => 'MONARC (VirtualBox VM)', // will be used for the label of the 2FA QRCode.
    'twoFactorAuthEnforced' => false,

    'email' => [
        'name' => 'MONARC',
        'from' => 'info@monarc.lu',
    ],

    'mospApiUrl' => 'https://objects.monarc.lu/api/',

    'monarc' => [
        'ttl' => 60,
        'salt' => '',
    ],

    'statsApi' => [
        'baseUrl' => 'http://127.0.0.1:$STATS_PORT',
        'apiKey' => '$STATS_SECRET_KEY',
    ],

    'import' => [
        'uploadFolder' => '/var/lib/monarc/fo/data/import/files',
        'isBackgroundProcessActive' => false,
    ],
];
EOF"


echo "--- Creation of the data bases… ---"
mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC -e "CREATE DATABASE monarc_cli DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;" > /dev/null
mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC -e "CREATE DATABASE monarc_common DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;" > /dev/null
echo "--- Populating MONARC DB… ---"
sudo -u monarc mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC monarc_common < db-bootstrap/monarc_structure.sql > /dev/null
sudo -u monarc mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC monarc_common < db-bootstrap/monarc_data.sql > /dev/null
echo -e "--- Migrating MONARC DB… ---"
sudo -u www-data php ./vendor/robmorgan/phinx/bin/phinx migrate -c module/Monarc/FrontOffice/migrations/phinx.php
sudo -u www-data php ./vendor/robmorgan/phinx/bin/phinx migrate -c module/Monarc/Core/migrations/phinx.php


echo -e "--- Create initial user… ---"
sudo -u www-data php ./vendor/robmorgan/phinx/bin/phinx seed:run -c ./module/Monarc/FrontOffice/migrations/phinx.php


echo -e "--- Add a VirtualHost for MONARC… ---"
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


echo -e "--- Restarting Apache… ---"
sudo systemctl restart apache2.service > /dev/null


echo -e "\n--- Installing the stats service… ---\n"
sudo apt-get -y install docker docker-compose
git clone https://github.com/monarc-project/stats-service $STATS_PATH
cd $STATS_PATH
docker-compose up -d


sudo bash -c "cat << EOF > /etc/systemd/system/statsservice.service
[Unit]
Description=MONARC Stats service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$STATS_PATH
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload > /dev/null
sleep 1
sudo systemctl enable statsservice.service > /dev/null
sleep 1
sudo systemctl restart statsservice > /dev/null
#systemctl status statsservice.service


echo -e "--- Create a collect-stats run every day. ---"
sudo bash -c "cat > /etc/cron.daily/collect-stats <<EOF
#!/bin/sh
cd /var/lib/monarc/fo/ ; php bin/console monarc:collect-stats
EOF"


echo -e "--- Post configurations… ---"
sudo bash -c "cat << EOF > /etc/issue
Welcome to the MONARC Virtual Machine!

MONARC Web interface is available at: http://\4

Stats Service is available at: http://\4:$STATS_PORT/api/v1/swagger.json

If you find any bugs:
https://github.com/monarc-project/MonarcAppFO/issues


EOF"


TIME_END=$(date +%s)
TIME_DELTA=$(expr ${TIME_END} - ${TIME_START})

echo -e "--- MONARC is ready! ---"
echo -e "Login and passwords for the MONARC image are the following:"
echo -e "MONARC application: admin@admin.localhost:admin"
echo -e "SSH login: monarc:password"
echo -e "Mysql root login: $DBUSER_ADMIN:$DBPASSWORD_ADMIN"
echo -e "Mysql MONARC login: $DBUSER_MONARC:$DBPASSWORD_MONARC"

echo -e "The generation took ${TIME_DELTA} seconds"
