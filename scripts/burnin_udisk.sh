#!/bin/bash
ROOT_DIR=`pwd`
mountpoint=$ROOT_DIR/log
mkdir -p ${mountpoint}/udisk
testTime=`date +%Y%m%d.%H.%M.%S`
LOGFILE="${mountpoint}/udisk/${testTime}.txt"
fifoStr="01234567890abcdefghijklmnopqrstuvwxyz!@#$%^&*()"

read_test_res() {
	#echo "[`date +%Y%m%d.%H.%M.%S`]    $1 $2"
	echo "[`date +%Y%m%d.%H.%M.%S`]    $1 $2" | tee -a $LOGFILE
}
file_RW_test() {
	declare -i count
	count=0
	TMPDIR=`mktemp -d`

	if [[ $3 != "" ]]; then
		if [[ ! -e "/dev/$1" ]]; then
			read_test_res "$3($1) : /dev/$1 no exist" "Failed"
			echo "Test is completed!!!" >> $LOGFILE
			return
		fi
		sync&& umount "/dev/$1" &>/dev/null
		if `mount "/dev/$1" $TMPDIR &>/dev/null` ;then
			if [[ $2 -eq 0 ]]; then
				while true
				do
					((count++))
					echo $fifoStr > "$TMPDIR/test.txt"
					ReadStr=`cat $TMPDIR/test.txt`
					if [ $fifoStr == $ReadStr ]; then
						read_test_res "$3($1) : Read/Write" "Pass (count:$count / infinite)"
					else
						read_test_res "$3($1) : Read/Write" "Failed (count:$count / infinite)"
					fi
					sleep 1
					rm $TMPDIR/test.txt
				done
			else
				for((i=1;i<=$2;i++)) do
					((count++))
					echo $fifoStr > "$TMPDIR/test.txt"
					ReadStr=`cat $TMPDIR/test.txt`
					if [ $fifoStr == $ReadStr ]; then
						read_test_res "$3($1) : Read/Write" "Pass (count:$count / $2)"
					else
						read_test_res "$3($1) : Read/Write" "Failed (count:$count / $2)"
					fi
					sleep 1
					rm $TMPDIR/test.txt
				done
				echo -e "Test is completed!!!" | tee -a $LOGFILE
			fi
			sync && umount "/dev/$1" &>/dev/null && sync && sleep 1
		else
			read_test_res "$3($1) : /dev/$1 cannot be mounted correctly" "Failed"
			echo -e "Test is completed!!!" | tee -a $LOGFILE
		fi
		echo 'Press any key to continue...'
		rm -rf $TMPDIR
	fi
}
verify()
{
	if [ $USER != "root" ]
	then
		echo "is not root ?"
		exit
	fi
	if [ $# -lt 2 ]; then
		echo -e "$(
cat << EOF
\e[31mPlease enter USB port number and test count.
Ex:Test USB sda1 with 2 times.
$./burnin_udisk.sh sda1 2\e[0m
EOF
		)"
		exit 0
	fi
}

verify $@
echo "uDisk Log file : ${LOGFILE}"
if [ $# -lt 3 ]; then
	file_RW_test $1 $2 "USB"
else
	file_RW_test $1 $2 $3
fi
