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


# Stats service
PYTHON_VERSION='3.9.5'
STATS_PATH='/home/monarc/stats-service'
STATS_HOST='0.0.0.0'
STATS_PORT='5005'
STATS_DB_NAME='statsservice'
STATS_DB_USER='sqlmonarcuser'
STATS_DB_PASSWORD="sqlmonarcuser"
STATS_SECRET_KEY="$(openssl rand -hex 32)"


# Timing creation
TIME_START=$(date +%s)

# php.ini configuration
upload_max_filesize=200M
post_max_size=200M
max_execution_time=200
max_input_time=223
memory_limit=1024M
PHP_INI=/etc/php/7.4/apache2/php.ini

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


sudo apt -y install software-properties-common
sudo add-apt-repository ppa:ondrej/php
sudo apt-get update

echo "--- Installing PHP-specific packages… ---"
sudo apt-get -y install php7.4 apache2 libapache2-mod-php php7.4-curl php7.4-gd php7.4-mysql php7.4-apcu php7.4-xml php7.4-mbstring php7.4-intl php7.4-imagick php7.4-zip php7.4-bcmath > /dev/null
sudo apt-get -y remove php8.0-cli

php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '756890a4488ce9024fc62c56153228907f1545c228516cbf63f885e036d37e9a59d27d63f46af1d4d07ee0f76181c7d3') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php --install-dir=/tmp --filename=composer
php -r "unlink('composer-setup.php');"
mv /tmp/composer /usr/local/bin/composer


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
sudo -u monarc composer install -o --no-dev

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


echo "--- Installation Node, NPM and Grunt… ---"
curl -sL https://deb.nodesource.com/setup_16.x | sudo bash -
sudo apt-get install -y nodejs
sudo npm install -g grunt-cli
sudo npm install -g node-gyp


echo -e "\n--- Installing the stats service… ---\n"
# see up-to-date processe here:
# https://github.com/monarc-project/stats-service/blob/master/contrib/install.sh

sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
libreadline-dev libsqlite3-dev wget llvm libncurses5-dev libncursesw5-dev \
xz-utils tk-dev libffi-dev liblzma-dev python-openssl python3-distutils


# install a newer version of Python
curl https://pyenv.run | bash
sudo chown -R monarc:monarc /home/monarc/.pyenv
sudo chmod -R 777 /home/monarc/.pyenv # prevents 'pyenv: cannot rehash: /home/monarc/.pyenv/shims isn't writable'

export PATH="/home/monarc/.pyenv/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv virtualenv-init -)"

sudo -u monarc echo 'export PYENV_ROOT="/home/monarc/.pyenv"' >> /home/monarc/.profile
sudo -u monarc echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> /home/monarc/.profile
sudo -u monarc echo 'eval "$(pyenv init --path)"' >> /home/monarc/.profile
sudo -u monarc bash -c 'source /home/monarc/.profile'
pyenv install $PYTHON_VERSION
pyenv global $PYTHON_VERSION

sudo apt-get -y install postgresql
sudo -u postgres psql -c "CREATE USER $STATS_DB_USER WITH PASSWORD '$STATS_DB_PASSWORD';"
sudo -u postgres psql -c "ALTER USER $STATS_DB_USER WITH SUPERUSER;"


cd ~
curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py -o get-poetry.py
python get-poetry.py
sudo chown -R monarc:monarc /home/monarc/.poetry
rm get-poetry.py
export FLASK_APP=runserver.py
export PATH="$PATH:$HOME/.poetry/bin"
export STATS_CONFIG=production.py
echo 'export PATH="$PATH:$HOME/.poetry/bin"' >> ~/.bashrc
echo 'export FLASK_APP=runserver.py' >> ~/.bashrc
echo 'export STATS_CONFIG=production.py' >> ~/.bashrc
bash -c 'source /home/monarc/.bashrc'
bash -c 'source $HOME/.poetry/env'


sudo mkdir -p $STATS_PATH
sudo chown monarc:monarc $STATS_PATH
git clone https://github.com/monarc-project/stats-service $STATS_PATH
sudo chown -R monarc:monarc $STATS_PATH
cd $STATS_PATH
sudo -u monarc npm ci
poetry install --no-dev

sudo -u monarc cat > $STATS_PATH/instance/production.py <<EOF
HOST = '$STATS_HOST'
PORT = $STATS_PORT
DEBUG = False
TESTING = False
INSTANCE_URL = 'http://127.0.0.1:$STATS_PORT'

ADMIN_EMAIL = 'info@cases.lu'
ADMIN_URL = 'https://www.cases.lu'

REMOTE_STATS_SERVER = 'https://dashboard.monarc.lu'

DB_CONFIG_DICT = {
    'user': '$STATS_DB_USER',
    'password': '$STATS_DB_PASSWORD',
    'host': 'localhost',
    'port': 5432,
}
DATABASE_NAME = '$STATS_DB_NAME'
SQLALCHEMY_DATABASE_URI = 'postgresql://{user}:{password}@{host}:{port}/{name}'.format(
    name=DATABASE_NAME, **DB_CONFIG_DICT
)
SQLALCHEMY_TRACK_MODIFICATIONS = False

SECRET_KEY = '$STATS_SECRET_KEY'

LOG_PATH = './var/stats.log'

MOSP_URL = 'https://objects.monarc.lu'
EOF

mkdir var
touch var/stats.log
sudo chown monarc:monarc var/stats.log
sudo chmod 777 var/stats.log

export FLASK_APP=runserver.py
export STATS_CONFIG=production.py

FLASK_APP=runserver.py poetry run flask db_create
FLASK_APP=runserver.py poetry run flask db_init
FLASK_APP=runserver.py poetry run flask client_create --name ADMIN --role admin


sudo bash -c "cat << EOF > /etc/systemd/system/statsservice.service
[Unit]
Description=MONARC Stats service
After=network.target

[Service]
User=monarc
Environment=LANG=en_US.UTF-8
Environment=LC_ALL=en_US.UTF-8
Environment=FLASK_APP=runserver.py
Environment=FLASK_ENV=production
Environment=STATS_CONFIG=production.py
Environment=FLASK_RUN_HOST=$STATS_HOST
Environment=FLASK_RUN_PORT=$STATS_PORT
WorkingDirectory=$STATS_PATH
ExecStart=/home/monarc/.pyenv/shims/python /home/monarc/.poetry/bin/poetry run flask run
Restart=always

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload > /dev/null
sleep 1
sudo systemctl enable statsservice.service > /dev/null
sleep 3
sudo systemctl restart statsservice > /dev/null
#systemctl status statsservice.service

# Create a new client and set the apiKey.
cd $STATS_PATH ; apiKey=$(poetry run flask client_create --name admin_localhost | sed -nr 's/Token: (.*)$/\1/p')
cd $PATH_TO_MONARC


echo "--- Configuration of MONARC data base connection… ---"
cd $PATH_TO_MONARC
sudo -u monarc cat > config/autoload/local.php <<EOF
<?php
\$package_json = json_decode(file_get_contents('./package.json'), true);

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

    'activeLanguages' => array('fr','en','de','nl','es','it','ja','pl','pt','ru','zh'),

    'appVersion' => \$package_json['version'],

    'checkVersion' => false,
    'appCheckingURL' => 'https://version.monarc.lu/check/MONARC',

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
        'apiKey' => '$apiKey',
    ],
];
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


echo "--- Update the project… ---"
sudo -u monarc ./scripts/update-all.sh


echo "--- Create initial user and client ---"
sudo -u www-data php ./vendor/robmorgan/phinx/bin/phinx seed:run -c ./module/Monarc/FrontOffice/migrations/phinx.php


echo "--- Restarting Apache… ---"
sudo systemctl restart apache2.service > /dev/null


echo "--- Create a collect-stats run every day. ---"
sudo bash -c "cat > /etc/cron.daily/collect-stats <<EOF
#!/bin/sh
cd /var/lib/monarc/fo/ ; php bin/console monarc:collect-stats
EOF"


echo "--- Post configurations… ---"
echo -e "Welcome to the MONARC VM.\nMy IP address is: \4\n" | sudo tee /etc/issue



TIME_END=$(date +%s)
TIME_DELTA=$(expr ${TIME_END} - ${TIME_START})

echo "--- MONARC is ready! ---"
echo "Login and passwords for the MONARC image are the following:"
echo "MONARC application: admin@admin.localhost:admin"
echo "SSH login: monarc:password"
echo "Mysql root login: $DBUSER_ADMIN:$DBPASSWORD_ADMIN"
echo "Mysql MONARC login: $DBUSER_MONARC:$DBPASSWORD_MONARC"

echo "The generation took ${TIME_DELTA} seconds"
