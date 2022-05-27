BIN_DIR="../../../bin"
DATA_DIR="../../../var/Rnp2021/df/ttls"
SCHEMA_DIR="../../../servers/df/ttls"
WWW_DIR="../../../www/Rnp2021"
LOG_FILE="../../../var/logs/df_ttls_inject.log"

HOSTNAME="http://127.0.0.1"
PORT=9001

START_DATE=20210901
END_DATE=20211231 # 20210915
SCHEMA="$SCHEMA_DIR/schema_ttls.json"

TC_SERVER_NAME="tc_server"

cd $(dirname "$0")
v=`ps awx | grep -c "${TC_SERVER_NAME} -l[ ]${PORT}"`
if  [ $v -ne 0 ] ; then exit; fi

#--------------------------
${BIN_DIR}/${TC_SERVER_NAME} -l ${PORT} -w ${WWW_DIR} -s ${SCHEMA} -W &



#--------------------------
#${BIN_DIR}/tc_server -l ${PORT} -w ${WWW_DIR} -s ${SCHEMA} -W &

sleep 2

# carga historica
/usr/bin/python3 ${BIN_DIR}/inject_files.py -u ${HOSTNAME}:${PORT} -p ${DATA_DIR}/ -d ${START_DATE} -e ${END_DATE} > ${LOG_FILE}
