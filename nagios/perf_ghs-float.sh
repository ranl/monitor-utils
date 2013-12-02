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

# Info
# 
# Get usage data from a GHS license server via the web managment console
# use mainly for performance monitoring

function FError() {
	echo "Syntax Error !"
	echo "$0 [license server name] [port] [feature name] [/path/to/ghs/log/file]"
	echo "port = port of the license web port"
	exit 1
}

if [ $# != 4 ]
then
	FError
fi

if [ `echo $2 | grep -q ^[[:digit:]]*$ ; echo $?` != 0 ]
then
	FError
fi

if [ ! -f "$4" ]
then
	FError
fi

server="$1"
port="$2"
feature="$3"
log_file="$4"

min=`date +%M | cut -c 2`
log_date_search="`date +%d``date +%b``date +%y` `date +%H`:`date +%M | cut -c 1`"
if [ $min -lt 5 ]
then
	min_list="0 1 2 3 4"
else
	min_list="5 6 7 8 9 10"
fi

random_file=/tmp/$RANDOM
while_file=/tmp/$RANDOM
denied_file=/tmp/$RANDOM
export msg="$server:$port is up"
export perf_data=""

if [ ! -f $log_file ]
then
	echo "$log_file doesn't exists !"
	exit 2
fi

wget http://$server:$port -q -O $random_file
if [ $? != 0 ]
then
	msg="$server:$port is down"
	echo "$msg"
	exit 2
fi

cat $random_file | grep -v ^\< | grep -v ^$ | grep -v ^\ | sed -n '1,4!p' | sed -e 's/<A HREF.*//g' -e 's/\s*<TD ALIGN=\"CENTER\">//g' -e 's/<\/TD>//g' | sed -n /^$feature\$/,+2p > $while_file

feature_exists=`head -n 1 $while_file | grep -q ^$feature$ ; echo $?`

if [ $feature_exists != 0 ]
then
	FError
fi

export counter=0
while read line
do
	counter=`expr $counter + 1`
	case $counter in
		2 )
			export total="$line"
		;;
		3 )
			export used="$line"

			# Missed Licensed request
			for m in $min_list
			do
				grep "^${log_date_search}${m}" $log_file  | grep "license denied: no $feature licenses available"$ | awk '{print $3}' >> $denied_file
			done
			miss_count=`awk '{print $1}' $denied_file | sort | uniq | wc -l`
			
			perf_data="total=${total};0;0 used=${used};0;0 missed_users=${miss_count};0;0"
		;;
	esac
	
done < $while_file

rm -rf $random_file $denied_file $while_file
echo "$msg | ${perf_data}"
exit 0
