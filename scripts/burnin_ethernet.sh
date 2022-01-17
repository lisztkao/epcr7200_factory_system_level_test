#!/bin/bash
ROOT_DIR=`pwd`
mountpoint=$ROOT_DIR/log
mkdir -p ${mountpoint}/ethernet
testTime=`date +%Y%m%d.%H.%M.%S`
LOGFILE="${mountpoint}/ethernet/${testTime}.txt"

ethernet_test() {
	declare -i count
	count=0
	if [[ ! -e "${ROOT_DIR}/scripts/burnin_ping_IP_config.sh" ]]; then 
		WEBSERVER=`ifconfig $1 | grep 'inet ' | cut -d: -f2 | awk '{print $2}' | awk 'BEGIN {FS="."} {print $1 "." $2 "." $3 "."}'`1
		echo "Don't edit Ping IP test configuration in main menu, currently use default $1 ping IP \"$WEBSERVER\" " 
		echo "[`date +%Y%m%d.%H.%M.%S`]    use default $1 ping IP \"$WEBSERVER\" " >> $LOGFILE
	else
		WEBSERVER=`cat ${ROOT_DIR}/scripts/burnin_ping_IP_config.sh |grep "$1_PING_IP" |awk 'BEGIN {FS="="} {print $2}'` 
		echo "Currently use $1 ping IP \"$WEBSERVER\" that has been configured in ./scripts/burnin_ping_IP_config.sh "
		echo "[`date +%Y%m%d.%H.%M.%S`]    use $1 ping IP \"$WEBSERVER\" " >> $LOGFILE
	fi

	if [[ $2 -eq 0 ]]; then
		while true;do
			((count++))
			echo "[`date +%Y%m%d.%H.%M.%S`]  ping $WEBSERVER  (count:$count / infinite)" | tee -a $LOGFILE
			(ping $WEBSERVER -c 1 2>&1 | tee -a $LOGFILE) 2>&1 > /dev/null
		done
	else	
		for((i=1;i<=$2;i++)) do
			((count++))
			echo "[`date +%Y%m%d.%H.%M.%S`]  ping $WEBSERVER  (count:$count / $2)" | tee -a $LOGFILE
			(ping $WEBSERVER -c 1 2>&1 | tee -a $LOGFILE) 2>&1 > /dev/null
		done
		echo "Test is completed!!!" | tee -a $LOGFILE
	fi
	echo 'Press any key to continue...'
}

verify()
{
	if [ $# -lt 2 ]; then
		echo -e "$(
cat << EOF
\e[31mPlease enter port number and test count.
Ex:Test ethernet eth0 with 2 times.
$./burnin_ethernet.sh eth0 2\e[0m
EOF
		)"
		exit 0
	fi
}

verify $@

echo "Ethernet Log file : ${LOGFILE}"
ethernet_test $1 $2
