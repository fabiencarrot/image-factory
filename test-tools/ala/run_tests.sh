#!/usr/bin/env bash

IMAGE=${IMAGE:="Windows Server 2012 R2"}
FLAVOR=${FLAVOR:="n1.cw.highcpu-2"}
ALT_FLAVOR=${ALT_FLAVOR:="n1.cw.highcpu-3"}
NETWORK=${NETWORK:="1e3d7d66-7508-437f-bbcf-f38ca236c28b"}
POOL=${POOL:="6ea98324-0f14-49f6-97c0-885d1b8dc517"}
KEY=${KEY:="test_win"}
PRIVATE_KEY=${PRIVATE_KEY:="/home/arezmerita/Downloads/test_win.pem"}
LOG_FILE=${LOG_FILE:="test.log"}
SSH_USER=${SSH_USER:="cloud"}
HOST="google.com"
TIMEOUT=180
SMALL_SLEEP=60
MINI_SLEEP=10
USER_DATA_FILE=${USER_DATA_FILE:="./userdata.txt"}
RETRY=${RETRY:=10}
WIN=${WIN:=0}
SLES=${SLES:=0}
WIN_PASSWORD="ZC83nSQZHpVYtj"
VOLUME_SIZE=1
REBOOT=0


source functions.sh

if [[ ! ("$OS_TENANT_NAME" && "$OS_USERNAME" && "$OS_PASSWORD" && "$OS_AUTH_URL") ]]
then
    echo "You must provide credentials"
    exit
fi

token=`keystone token-get | grep " id " | awk '{print $4}'`
if [ ! $token ]
then
    echo "Wrong credentials"
    exit
fi

if [ ! -f $LOG_FILE ]
then
    touch $LOG_FILE
else
    truncate -s 0 $LOG_FILE
fi

if [ $WIN -eq 1 ]
then
    echo "Running window tests"
    run_all_windows_tests
else
    if [ $# -eq 0 ]
    then
        echo "Running all tests"
        run_all_tests
    else
        echo "Running tests: $@"
        run_some_tests $@
    fi
fi



