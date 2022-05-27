#!/bin/bash

# $1 = PARENT_DIR
# $2 = PORT
if [ $# != 1 ] && [ $# != 2 ]
then
    echo "Usage: sudo bash install.sh <PARENT_DIR>"
    echo "Usage: sudo bash install.sh <PARENT_DIR> <INTERFACE_PORT>"
    echo "Example: sudo bash install.sh /home/arthur localhost:8080"
    exit 1
fi

# replace PARENT_DIR in nginx_to_install.conf with $1
PARENT_DIR=$(echo ${1} | sed 's/\//\\\//g')
sed -i "s/PARENT_DIR/$PARENT_DIR/g" openresty/nginx_to_install.conf

# saves the original nginx.conf 
sudo mv /usr/local/openresty/nginx/conf/nginx.conf /usr/local/openresty/nginx/conf/original_nginx.conf  

# copy ningx_to_install.conf to final place
sudo cp openresty/nginx_to_install.conf /usr/local/openresty/nginx/conf/nginx.conf


# append the lines below, including BEGIN and END lines, to the CRON file being edited
CHECK_TINYCUBES_CMD="* * * * * bash $1/nb/cron/check_tinycubes_servers.sh"
CHECK_BORESCOPE_CMD="* * * * * bash $1/nb/cron/check_borescope_servers.sh"
crontab -l > crontab_file
echo "#-----------------------[BEGIN BORESCOPE]-----------------------" >> crontab_file
echo "$CHECK_TINYCUBES_CMD" >> crontab_file
echo "$CHECK_BORESCOPE_CMD" >> crontab_file
echo "#-----------------------[END BORESCOPE]-------------------------" >> crontab_file
crontab crontab_file
rm crontab_file

if [ $# == 2 ]
then
    if [ ${2:0:4} == "http" ]
    then
        PORT=${2:7}
    fi
    sed -i "s/127.0.0.1:8009/$PORT/g" www/assets/config.json
fi
