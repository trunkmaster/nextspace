#!/bin/sh

PROG_PATH="/usr/NextSpace/Apps/Login.app/Login"
PROG_ARGS="--GNU-Debug=dealloc"

PROG_NAME=`basename ${PROG_PATH}`

WS_PID="`ps auxw|grep ${PROG_PATH}|grep -v grep|grep -v /bin/sh|awk -c '{print $2}'`"
if [ "$WS_PID" == "" ];then
    echo "Starting new '${PROG_NAME}' instance..."
    gdb -q --args ${PROG_PATH} ${PROG_ARGS}
else
    echo "Found '${PROG_NAME}' PID: ${WS_PID}"
    gdb ${PROG_PATH} -p ${WS_PID}
fi
