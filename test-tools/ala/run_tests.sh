#!/usr/bin/env bash

IMAGE=$1
FLAVOR=${FLAVOR:="n1.cw.standard-1"}
ALT_FLAVOR=${ALT_FLAVOR:="n1.cw.standard-2"}
NETWORK=${NETWORK:="a8816f03-cace-4c39-904e-d3fafdbfbe86"}
POOL=${POOL:="6ea98324-0f14-49f6-97c0-885d1b8dc517"}
KEY=${KEY:="jenkins-ci"}
PRIVATE_KEY=${PRIVATE_KEY:="/var/lib/jenkins/.ssh/jenkins-ci.pem"}
LOG_FILE=${LOG_FILE:="test.log"}
SSH_USER=${SSH_USER:="cloud"}
HOST="google.com"

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
if [ -z "$MY_PATH" ] ; then
    # error; for some reason, the path is not accessible
    # to the script (e.g. permissions re-evaled after suid)
    exit 1  # fail
fi


USER_DATA_FILE="$MY_PATH/userdata.txt"
source $MY_PATH/functions.sh

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

run_all_tests
