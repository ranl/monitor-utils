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

function FError()
{
	echo "Syntax:"
	echo "$0 [svn server] [http | svn | https] [repos path] [location to check-out] [username] [password]"
	echo "for this check you'll need to create a repository name nagios"
	echo "Example:"
	echo "$0 svnsrv http,https CM ${RANDOM}"
	exit 1
}

function FCheckHttps()
{
mkdir -p $WORKINGCOPY
cd $WORKINGCOPY
svn co https://${SVNSRV}/${REPOPATH}/nagios --no-auth-cache --config-dir /home/nagios/.subversion --username $SVNUSER --password $SVNPASS $WORKINGCOPY &> /dev/null
if [ $? != 0 ]
then
	rm -rf $WORKINGCOPY
	ERR=`expr $ERR + 1`
	MSG="$MSG https: Error"
	PERF="$PERF https=0;0;0;;"
else
	rm -rf $WORKINGCOPY
	ERR=`expr $ERR + 0`
	MSG="$MSG https: ok"
	PERF="$PERF https=1;0;0;;"
fi
}

function FCheckHttp()
{
mkdir -p $WORKINGCOPY
cd $WORKINGCOPY
svn co http://${SVNSRV}/${REPOPATH}/nagios --no-auth-cache --config-dir /home/nagios/.subversion --username $SVNUSER --password $SVNPASS $WORKINGCOPY &> /dev/null
if [ $? != 0 ]
then
	rm -rf $WORKINGCOPY
	ERR=`expr $ERR + 1`
	MSG="$MSG http: Error"
	PERF="$PERF http=0;0;0;;"
else
	rm -rf $WORKINGCOPY
	ERR=`expr $ERR + 0`
	MSG="$MSG http: ok"
	PERF="$PERF http=1;0;0;;"
fi
}

function FCheckSvn()
{
mkdir -p $WORKINGCOPY
cd $WORKINGCOPY
svn co svn://${SVNSRV}/nagios --no-auth-cache --config-dir /home/nagios/.subversion --username $SVNUSER --password $SVNPASS $WORKINGCOPY &> /dev/null
if [ $? != 0 ]
then
	rm -rf $WORKINGCOPY
	ERR=`expr $ERR + 1`
	MSG="$MSG svn: Error"
	PERF="$PERF svn=0;0;0;;"
else
	rm -rf $WORKINGCOPY
	ERR=`expr $ERR + 0`
	MSG="$MSG svn: ok"
	PERF="$PERF svn=1;0;0;;"
fi
}

if [ $# != 4 ]
then
	FError
fi

SVNSRV="$1"
PROTOCOL=`echo $2 | sed 's/,/ /g'`
REPOPATH="$3"
WORKINGCOPY="$4"
SVNPORT="3690"
HTTPPORT="80"
HTTPSPORT="443"
SVNUSER="$5"
SVNPASS="$6"
MSG=""
PREF=""
ERR="0"

for proto in $PROTOCOL
do
	case $proto in
		"https" )
			FCheckHttps
		;;
		"http" )
			FCheckHttp
		;;
		"svn" )
			FCheckSvn
		;;
		* )
			FError
		;;
	esac
done



if [ $ERR = 0 ]
then
	echo "$MSG = OK | $PERF"
	exit 0
else
	echo "$MSG = CRITICAL | $PERF"
	exit 2
fi

echo "Looking OK | Server:$SVNSRV Protocols:$PROTOCOL"

