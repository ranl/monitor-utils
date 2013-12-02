#!/bin/bash

#####################################
#####################################
### ______               _     =) ###
### | ___ \             | |       ###
### | |_/ / __ _  _ __  | |       ###
### |    / / _` || '_ \ | |       ###
### | |\ \| (_| || | | || |____   ###
### \_| \_|\__,_||_| |_|\_____/   ###
#####################################
#####################################

# Settings

lmutil="/path/to/lmutil"

function FError() {
	echo "Syntax:"
	echo "$0 [licesnse server dns name] [port #]"
	exit 3
}

if [ $# != 2 ]
then
	FError
fi

server=$1
port=$2

$lmutil lmstat -c ${port}@${server} &> /dev/null
ERR=$?
if [ $ERR == 0 ]
then
	echo "Flexlm: OK - ${port}@${server}| flexlm=1"
	exit 0
else
	echo "Flexlm: Crit - ${port}@${server} | flexlm=0"
	exit 2
fi
