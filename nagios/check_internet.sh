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

# Checking User Input
function FError()
{
	echo "Syntax:"
	echo "$0 [url] [number of tries] [time out]"
	echo "Example:"
	echo "$0 www.google.com 2 5"
	exit 1
}

if [ $# != 3 ]
then
	FError
fi

url="$1"

if [ `echo $2 | grep -q ^[[:digit:]]*$ ; echo $?` == 0 ]
then
	tries="$2"
else
	FError
fi

if [ `echo $3 | grep -q ^[[:digit:]]*$ ; echo $?` == 0 ]
then
	timeout="$3"
else
	FError
fi

wget=`which wget`


wget_code=`$wget $url -q -O /dev/null -t $tries --timeout $timeout ; echo $?`

if [ $wget_code == 0 ]
then
	echo "Internet Access Ok - $url | internet=1;0;0"
	exit 0
else
	echo "Internet Access Failed - $url | internet=0;0;0"
	exit 2
fi

