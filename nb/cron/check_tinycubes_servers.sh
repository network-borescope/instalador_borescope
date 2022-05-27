#!/bin/bash

#SERVERS_ROOT=`pwd`/../servers
BASEDIR=$(dirname $0)
SERVERS_ROOT="$BASEDIR"/../servers

#------------------------------------- template
#SUBDIR="server's subdirectory"
# uncomment the next line
#sh ${SERVERS_ROOT}/${SUBDIR}/run.sh

#------------------------------------- ttls
#SUBDIR="server's subdirectory"
SUBDIR="df/ttls"
bash ${SERVERS_ROOT}/${SUBDIR}/run.sh &

#------------------------------------- dns
#SUBDIR="server's subdirectory"
SUBDIR="df/dns"
bash ${SERVERS_ROOT}/${SUBDIR}/run.sh &

#------------------------------------- serv
#SUBDIR="server's subdirectory"
SUBDIR="df/serv"
bash ${SERVERS_ROOT}/${SUBDIR}/run.sh &

#------------------------------------- perfSONAR
#SUBDIR="server's subdirectory"
SUBDIR="perfSONAR"
bash ${SERVERS_ROOT}/${SUBDIR}/run.sh &
