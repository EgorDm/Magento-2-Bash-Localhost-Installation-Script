SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
CONFIGPATH=$SCRIPTPATH/config.sh
if [ -e $CONFIGPATH ]
then
    . $CONFIGPATH
else
    . $SCRIPTPATH/config.sample.sh
fi

$MC_COMMAND auth:info
$MC_COMMAND ssh-key:add --yes

if [ "$1" = "--help" ] || [ "$1" = "-h" ] ; then
  echo "The options available for this command:
        mc_install 1 2 3 4
        1: project identifier
        2: The name of the website"
  exit 0
fi


PROJECT=$1
NAME=$2


if [ -z "$NAME" ]; then
	echo "enter name. Will be used as  $DOMAIN_PREFIX<yourname>$DOMAIN_SUFFIX"
	exit;
fi

VALET_DOMAIN=$DOMAIN_PREFIX$NAME
DIRECTORY=$DOMAINS_PATH/$VALET_DOMAIN$FOLDER_SUFFIX
DOMAIN=$VALET_DOMAIN$DOMAIN_SUFFIX
MYSQL_DATABASE_NAME=$MYSQL_DATABASE_PREFIX$NAME
MYSQL_DATABASE_NAME="${MYSQL_DATABASE_NAME//./_}"
if [[ $EDITION != "custom-"* ]]; then
    if [ -d "$DIRECTORY" ]; then
        echo "already exists"
        exit;
    fi
fi
## Create Database
mysql -h$MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE_NAME\`"

COMPOSER="composer"
PHP="php"
if [ "$VERSION" ]; then
    if [[ $VERSION = "2.1."* ]]; then
        if [ "$PHP7" ]; then
            PHP=$PHP7
        fi
        if [ "$COMPOSER_PHP7" ]; then
            COMPOSER=$COMPOSER_PHP7
        fi
    fi
fi

## Download Magento
$MC_COMMAND project:get $PROJECT $DIRECTORY
cd $DIRECTORY
$MC_COMMAND build --no-build-hooks

## Install Sample Data
mkdir $DIRECTORY/var/composer_home

## Copy Json Auth
if [ -e $COMPOSER_AUTH_JSON_FILE_PATH ]; then
        cp $COMPOSER_AUTH_JSON_FILE_PATH $DIRECTORY/var/composer_home/auth.json
fi

## Install Magento
URL="http://$DOMAIN"
if [ "$secure" = "true" ]; then
	URL="https://$DOMAIN"
fi

rm -rf $DIRECTORY/generated/*
rm -rf $DIRECTORY/var/cache/*

$PHP $DIRECTORY/bin/magento setup:install --admin-firstname="$MAGENTO_USERNAME" --admin-lastname="$MAGENTO_USERNAME" --admin-email="$MAGENTO_USER_EMAIL" --admin-user="$MAGENTO_USERNAME" --admin-password="$MAGENTO_PASSWORD" --base-url="$URL" --backend-frontname="$MAGENTO_ADMIN_URL" --db-host="$MYSQL_HOST" --db-name="$MYSQL_DATABASE_NAME" --db-user="$MYSQL_USER" --db-password="$MYSQL_PASSWORD" --language=nl_NL --currency=EUR --timezone=Europe/Amsterdam --use-rewrites=1 --session-save=files

$PHP $DIRECTORY/bin/magento setup:upgrade


## Developer Settings
$PHP $DIRECTORY/bin/magento deploy:mode:set developer
$PHP $DIRECTORY/bin/magento cache:enable
$PHP $DIRECTORY/bin/magento cache:disable layout block_html collections full_page
### Generated PhpStorm XML Schema Validation
mkdir -p $DIRECTORY/.idea
$PHP $DIRECTORY/bin/magento dev:urn-catalog:generate $DIRECTORY/.idea/misc.xml

. $SCRIPTPATH/src/update_settings.sh

. $SCRIPTPATH/src/secure_domain.sh

. $SCRIPTPATH/src/nfs.sh


# Bitbucket START
echo Fill in the bitbucket repository name like teamname/reponame
read BITBUCKET_REPO
if [ -z "$BITBUCKET_REPO" ]; then
  echo You forgot to fill in the bitbucket repository URL, please fill it in like teamname/reponame
  read BITBUCKET_REPO
  if [ -z "$BITBUCKET_REPO"]; then
    echo Bitbucket Integration Skipped because no bitbucket repository URL was given
  fi
fi
echo Fill in the bitbucket oauth-consumer-key - https://devdocs.magento.com/guides/v2.3/cloud/integrations/bitbucket-integration.html#create-an-oauth-consumer
read BITBUCKET_KEY
if [ -z "$BITBUCKET_KEY" ]; then
  echo You forgot to fill in the bitbucket oauth-consumer-key, please fill it in
  read BITBUCKET_KEY
  if [ -z "$BITBUCKET_KEY"]; then
    echo Bitbucket Integration Skipped because no bitbucket oauth-consumer-key was given
  fi
fi

echo Fill in the bitbucket oauth-consumer-key - https://devdocs.magento.com/guides/v2.3/cloud/integrations/bitbucket-integration.html#create-an-oauth-consumer
read BITBUCKET_SECRET
if [ -z "$BITBUCKET_SECRET" ]; then
  echo You forgot to fill in the bitbucket oauth-consumer-secret, please fill it in
  read BITBUCKET_SECRET
  if [ -z "$BITBUCKET_SECRET"]; then
    echo Bitbucket Integration Skipped because no bitbucket oauth-consumer-secret was given
  fi
fi

echo "Setting up bitbucket integration"
$MC_COMMAND project:curl -p $PROJECT \/integrations -i -X POST -d '{"type": "bitbucket","repository": "'$BITBUCKET_REPO'","app_credentials": {"key": "'$BITBUCKET_KEY'","secret": "'$BITBUCKET_SECRET'"},"prune_branches": true,"fetch_branches": true,"build_pull_requests": true,"resync_pull_requests": true}'
exit;
# Bitbucket END
