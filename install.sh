#!/bin/bash

# Author: Richard Henck (richard.henck@iqb.hu-berlin.de)

set -e

source config

### Check installed tools ###
{
  docker -v > /dev/null 2>&1
} || {
  echo "Docker not found, please install before running!"
  exit 1
}

{
  docker-compose -v > /dev/null 2>&1
} || {
  echo "Docker-compose not found, please install before running!"
  exit 1
}
echo "Docker and docker-compose found..."
{
  make -v > /dev/null 2>&1
} || {
  echo "Make not found! It is recommended to manage the application."
  read  -p 'Continue anyway? (y/N): ' -r -n 1 -e CONTINUE

  if [[ ! $CONTINUE =~ ^[yY]$ ]]; then
    exit 1
  fi
}

### Download package ###
if ls $APP_NAME-*.tar 1> /dev/null 2>&1
  then
    PACKAGE_FOUND=true
    if [ $(ls $APP_NAME-*.tar | wc -l) -gt 1 ]
      then
        echo "Multiple packages found. Remove all but the one you want!"
        exit 1
    fi
    read -p "Installation package found. Do you want to check for and download the latest release anyway? [y/N]:" -r -n 1 -e DOWNLOAD
    DOWNLOAD=${DOWNLOAD:-n}
  else
    PACKAGE_FOUND=false
    read -p "No installation package found. Do you want to download the latest release? [Y/n]:" -r -n 1 -e DOWNLOAD
    DOWNLOAD=${DOWNLOAD:-y}
fi

if [ "$PACKAGE_FOUND" = 'false' ] && [[ ! $DOWNLOAD =~ ^[yY]$ ]]
  then
    echo "Can not continue without install package."
    exit 1
fi

if [[ $DOWNLOAD =~ ^[yY]$ ]]
  then
    echo 'Downloading latest package...'
    rm -f $APP_NAME-*.tar;
    curl -s $REPO_URL/releases/latest \
    | grep "browser_download_url.*tar" \
    | cut -d : -f 2,3 \
    | tr -d \" \
    | wget -qi -;
fi

echo 'Ready to install. Please input some parameters for customization:'
read  -p '1. Install directory: ' -e -i "`pwd`/$APP_NAME" TARGET_DIR
### Unpack application ###
mkdir -p $TARGET_DIR
tar -xf *.tar -C $TARGET_DIR
cd $TARGET_DIR

### Set up config ###
read  -p '2. Server Address (hostname (without subdomains) or IP): ' -e -i $(hostname) HOSTNAME
sed -i "s/localhost/$HOSTNAME/" .env
echo "HOSTNAME=$HOSTNAME" >> .env

echo '3. Other Settings'
echo ' Please carefully specify the parameters for database access. Accepting
 the defaults will put your installation at risk.
 Use the defaults only for tryout installations, never in production use cases!'
for var in "${!env_vars[@]}"
  do
    read  -p "$var: " -e -i ${env_vars[$var]} $var
    echo "$var=${env_vars[$var]}" >> .env
done

read  -p 'Use TLS? (y/N): ' -r -n 1 -e TLS
if [[ $TLS =~ ^[yY]$ ]]
then
  echo "The certificates need to be placed in config/certs and their name configured in config/cert_config.yml."
  sed -i 's/ws:/wss:/' .env
fi

### Populate Makefile ###
touch Makefile
echo "run:" >> Makefile
if [[ $TLS =~ ^[yY]$ ]]
then
  echo "	docker-compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.prod.tls.yml up" >> Makefile
  echo "run-detached:" >> Makefile
  echo "	docker-compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.prod.tls.yml up -d" >> Makefile
  echo "stop:" >> Makefile
  echo "	docker-compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.prod.tls.yml stop" >> Makefile
  echo "down:" >> Makefile
  echo "	docker-compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.prod.tls.yml down" >> Makefile
  echo "pull:" >> Makefile
  echo "	docker-compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.prod.tls.yml pull" >> Makefile
else
  rm docker-compose.prod.tls.yml
  echo "	docker-compose -f docker-compose.yml -f docker-compose.prod.yml up" >> Makefile
  echo "run-detached:" >> Makefile
  echo "	docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d" >> Makefile
  echo "stop:" >> Makefile
  echo "	docker-compose -f docker-compose.yml -f docker-compose.prod.yml stop" >> Makefile
  echo "down:" >> Makefile
  echo "	docker-compose -f docker-compose.yml -f docker-compose.prod.yml down" >> Makefile
  echo "pull:" >> Makefile
  echo "	docker-compose -f docker-compose.yml -f docker-compose.prod.yml pull" >> Makefile
fi

echo '
 --- INSTALLATION SUCCESSFUL ---
'
echo 'Check the settings and passwords in the file '.env' in the installation directory.'
