#!/bin/bash

#SERVERS_DIR=`pwd`/../borescope/servers
BASEDIR=$(dirname $0)
SERVERS_DIR="$BASEDIR"/../borescope/servers

SERVER_COUNT=`ps awx | grep -c -e ".*python3.*/post_processor_tcpd\.py"`
if  [ $SERVER_COUNT -ne 0 ] ; then exit; fi

/usr/bin/python3 ${SERVERS_DIR}/post_processor_tcpd.py &
