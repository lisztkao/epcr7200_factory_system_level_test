#!/bin/bash 
# AIR-020
Ver=1.0.0
LANG=C
LANGUAGE="en_US.UTF-8"
app_root_dir=`pwd`
GRAY='\e[30m'
CLEAR='\e[0m'

#grant_permission
if [ $USER != "root" ]
then
	echo "is not root ?"
	exit
fi

declare -A mmc_type_group
for i in `ls /sys/bus/mmc/devices/`
do
	mmc_type_group[$i]=`cat /sys/bus/mmc/devices/$i/type`
done

return_emmc_dev() {
	for i in "${!mmc_type_group[@]}"
	do
		if [[ "${mmc_type_group[$i]}" == "MMC" ]];then
			echo | ls /sys/bus/mmc/devices/$i/block/
		fi
	done
}

return_sd_dev() {
	for i in "${!mmc_type_group[@]}"
	do
		if [[ "${mmc_type_group[$i]}" == "SD" ]];then
			echo | ls /sys/bus/mmc/devices/$i/block/
		fi
	done
}

declare -A udisk_content_group
declare -A udisk_group
for i in `ls /sys/bus/usb/devices/`
do
	udisk_content_group[$i]=`ls /sys/bus/usb/devices/$i/host*/target*:0:0/*:0:0:0/block 2>&1`
done

return_udisk_dev() {
for i in "${!udisk_content_group[@]}" 
do
	#echo $i
	#echo ${udisk_content_group[$i]}
	if [[ "${udisk_content_group[$i]}" == sd* ]];then
		udisk_group[$i]="${udisk_content_group[$i]}"
	fi
done
}

sddev=`return_sd_dev`
return_udisk_dev

end_test() {
	echo "Finish."
}

function grant_permission(){
	sudo cat /etc/sudoers | grep "NOPASSWD"
	if [ "$?" == "1" ]; then
		sudo /bin/bash -c 'echo "ubuntu  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers'
	fi
}

h_pattern() {
	exit_h_parttern=0
	declare -i h_count
	#h_count=0
	while true;do
		#echo -ne "$h_count H "
		for coln in  39 30 31 32 33 34 35 36 37
		do
			#echo -ne "H"
			echo -ne "\e[${coln}mH"
			usleep $h_delay
		done
		#h_count=h_count+1
	done
}

exit_h_pattern() {
	kill $h_pid &>/dev/null
	trap - SIGINT
	exit_h_parttern=1
	print_menu_main
}

udisk_init() {
	if [[ ${#udisk_group[@]} -eq 0 ]];then
		echo "udisk no exist"
		udisk_exist=0
	else
		udisk_exist=1
		for i in "${!udisk_group[@]}"
		do
			echo "udisk ${udisk_group[$i]} exist"
		done
	fi
}

kill_process() {
	pidofcat=`ps | grep "$1" | head -n 1 | awk '{print $1}'`
	if [ ! -z "$pidofcat" -a "$pidofcat" != " " ]; then
			kill -9 $pidofcat &>/dev/null
			ps &>/dev/null
	fi
}

write_i210_macaddress()
{
	firmware="./bin/Dev_Start_I210_Copper_NOMNG_8Mb_A2_3.25_0.03.hex"
	tool="./bin/EepromAccessTool"
	mac=$1
	i210=`lspci | grep I210`
	if [ -z "${i210}" ]; then
		echo "There is no I210 Ethernet controller on PCIe bus."
		exit -1
	fi;
	i210_number=$(lspci | grep I210 |awk '{print $1}');
	echo ${i210_number}
	setpci -s ${i210_number} COMMAND=0007

	if [ ! -f $tool -o ! -f $firmware ]; then
		echo "The tool or firmware is not exist!"
		exit -1
	fi
	$tool -nic=1 -f=$firmware -mac=${mac}
}

system_init() {
	clear
	stty erase '^H'
	stty erase '^?'
	echo "wait ... "
	udisk_init

	enptest=$(ifconfig -a | grep eth[^0] | awk '{print $1}')
	if [[ "$enptest" == "" ]] ; then
	   enptest=$(ifconfig -a | grep enp | awk '{print $1}')
	fi
	eths=$(ifconfig -a | grep Ethernet | awk '{print $1;}')
	for i in ${eths[@]}; do
		ifconfig $i down 2>/dev/null 1>/dev/null
	done
}

print_menu_main() {
	echo 
	echo -e "\e[39m"
	echo "Test script Version : $Ver"
	echo "=========================================="
	echo "(0)	Run the pre-defined all-test list"
	echo "(1)	Run the self-defined test list"
	echo "(2)	Add test items in self-defined test list"
	echo "(3)	Check the test items in self-defined test list"
	echo "(4)	Clear all test items in self-defined test list"
	echo "(5)	Stop the current running test processes"
	echo "(6) 	[GBE] Flash eth0 mac address"
	echo "(7) 	[I210] Flash eth1 mac address"
	echo "(E/e)	exit the main menu"
	echo "=========================================="
}

print_menu_self_defined() {
	echo 
	echo -e "\e[39m"
	echo "Please add test items in self-defined test list"
	echo "=========================================="
	echo "(0) [DISPLAY] - [HDMI] test"
	echo "(1) [USB] - [USB Type-A Ports U-Disk Read\Write] test"
	echo "(2) [LAN] - [eth0 eth1] test"
	echo "(3) Check the test items in self-defined test list"
	echo "(4) Clear all test items in self-defined test list"
	echo "(E/e) exit the self-defined test list menu"
	echo "=========================================="
}

pause() {
	read -n 1 -p "$*" INP
	if [[ $INP != '' ]] ; then
		echo -ne '\b \n'
	fi
}

is_correct_config="true"

eth_system_config()
{
	ps |grep "udhcpc -i $1" |awk '{print $1;}' |xargs kill -9 &>/dev/null
	#ifconfig eth0 down &>/dev/null
	ifconfig $1 up &>/dev/null
	for((i=0;i<2;i++)) do
		udhcpc -i $1 -n &>/dev/null
		netIP=`ifconfig $1 | grep 'inet ' | cut -d: -f2 | awk '{print $2}'`
		if [[ $netIP == "" ]]; then
			if [[ $i -eq 1 ]]; then
				echo "$1 failed to get to IP,Please check the network connection or cancel $1 ethernet test"
				is_correct_config="false"
				return
			else
				continue
			fi
		else
			echo "eth0 IP: $netIP"
			is_correct_config="true"
			break
		fi
	done
}

check_system_config() {
	is_correct_config="true"
	if [[ $1 == "-enable" ]]; then
		if [[ ! -e "${app_root_dir}/scripts/burnin_wifi_config.sh" ]]; then
			echo "No wifi SSID or PASSWORD is currently configured, please run \"Edit the WiFi test configuration\" option of main menu"
			is_correct_config="false"
			return
		else
			SSID=`cat ${app_root_dir}/scripts/burnin_wifi_config.sh |grep 'SSID' |cut -c 6-`
			PASSWORD=`cat ${app_root_dir}/scripts/burnin_wifi_config.sh |grep 'PASSWORD' |cut -c 10-`
			if [[ $SSID == "" ]]; then
				echo "Current wifi SSID is empty,please run \"Edit the WiFi test configuration\" option of main menu"
				is_correct_config="false"
				return
			elif [[ ${#PASSWORD} -lt 8 ]]; then
				echo "Current wifi PASSWORD length is less than 8,please run \"Edit the WiFi test configuration\" option of main menu"
				is_correct_config="false"
				return
			else
				echo "Currently use wifi \"$SSID\" that has been configured in ./scripts/burnin_wifi_config.sh"
				is_correct_config="true"
			fi
		fi
		
		ps |grep 'udhcpc -i wlan0' |awk '{print $1;}' |xargs kill -9 &>/dev/null
		ps |grep 'wpa_supplicant' |awk '{print $1;}' |xargs kill -9 &>/dev/null
		ifconfig wlan0 down &>/dev/null
		ifconfig wlan0 up &>/dev/null
		# Disable RFKill
		if which rfkill > /dev/null; then
			rfkill unblock all
		fi
		wpa_passphrase "$SSID" "$PASSWORD" > /wpa.conf
		wpa_supplicant -Dnl80211 -c/wpa.conf -iwlan0 -B
		
		udhcpc wlan0 &>/dev/null
		is_correct_config="true"
		
		#for((i=0;i<2;i++)) do
		#	udhcpc -i wlan0 -n &>/dev/null
		#	netIP=`ifconfig wlan0 |grep 'inet addr' |cut -d : -f2 | awk '{print $1}'`
		#	if [[ $netIP == "" ]]; then
		#		if [[ $i -eq 1 ]]; then
		#			echo "wlan0 failed to get to IP,Please check the network connection or cancel wifi test"
		#			is_correct_config="false"
		#			return
		#		else
		#			continue
		#		fi
		#	else
		#		echo "wlan0 IP: $netIP"
		#		is_correct_config="true"
		#		break
		#	fi
		#done
	fi
	
	if [[ $3 == "-enable" ]]; then
		eth_system_config "eth0"
	fi

	if [[ $5 == "-enable" ]]; then
		eth_system_config "eth1"
	fi
}

is_self_defined_config="true"
do_test_self_defined() {
	is_self_defined_config="true"
	while [[ $is_self_defined_config == "true" ]];do
		print_menu_self_defined
		read -p "select function : " res
		case $res in
			0)
				echo "LC_ALL=en_US.UTF-8 /usr/bin/dbus-launch gnome-terminal --window --maximize -- /bin/bash -c './scripts/burnin_h_pattern.sh' 2>&1 &" >> ./run/burnin.sh
				echo "The configuration of the HDMI H-Pattern test has been written to the script ./run/burnin.sh"
				pause 'Press any key to continue...'
				;;
			1)
				read -p "uDisk Write/Read times (0 for infinite loop) : " loop 
				if [[ $loop == +([0-9]) ]]; then
					if [[ "$udisk_exist" == "1" ]]; then
						for i in "${!udisk_group[@]}"
						do
							echo "./scripts/burnin_udisk.sh ${udisk_group[$i]}1 $loop "USB" 2>&1 &"  >> ./run/burnin.sh
						done
						echo "The configuration of the uDisk test has been written to the script ./run/burnin.sh"
					else
						echo "udisk no exist"
					fi
				else
					echo "Your input is illegal, please configure this option again"
				fi 
				pause 'Press any key to continue...'
				;;
			2)
				read -p "Choose ethernet port (0 : eth0, 1: eth1 ) : " port
				read -p "Ping webserver times (0 for infinite loop) : " loop
				if [[ $loop == +([0-9]) ]]; then
					read -p "add eth$port ethernet test in self-defined test list? (Y/N) " res
					case $res in 
						Y|y|"")
						echo "./scripts/burnin_ethernet.sh eth$port $loop 2>&1 &" >> ./run/burnin.sh
						echo "The \"eth$port Ethernet test\" has been written to the script ./run/burnin.sh"
							;;
						*)
						echo "Don't add eth$port ethernet test in self-defined test list"
							;; 
					esac
				else
					echo "Your input is illegal, please configure this option again"
				fi 
				pause 'Press any key to continue...'
				;;
			3)
				if [[ ! -e "${app_root_dir}/run/burnin.sh" ]]; then
					echo "There is no test items in self-defined test list, please configure again"
					pause 'Press any key to continue...'
				else
					echo "The following is the test items in self-defined test list"
					#echo ""
					cat ${app_root_dir}/run/burnin.sh
					#echo ""
					pause 'Press any key to continue...'
				fi
				;;
			4)
				rm ./run/burnin.sh &>/dev/null
				echo "All test items in self-defined test list has been cleaned up"
				pause 'Press any key to continue...'
				;;
			Q|q|E|e)
				is_self_defined_config="false"
				echo "Exit the self-defined test list menu, return to the main menu"
				;;
			*)
				;;
		esac
	done
}

do_test() {
	echo 1 > /proc/sys/kernel/printk
	system_init 
	while true;do
		print_menu_main
		read -p "select function : " res
		case $res in 
			0)
				echo "The following is the test items in pre-defined all-test list" 
				echo ""
				cat ${app_root_dir}/run/burnin.sh.default
				echo ""
				read -p "Run the pre-defined all-test list using current configuration? (Y/N) " res
				case $res in 
					Y|y|"")
						check_system_config -enable wlan0 -enable eth0 -enable $enptest
						if [[ $is_correct_config == "true" ]]; then
							read -p "testing times:(0 for infinite loop) " loop
							if [[ $loop == +([0-9]) ]]; then
								if [[ -e "./cache.txt" ]]; then
									rm ./cache.txt &>/dev/null
								fi
								touch ./cache.txt &>/dev/null
								./run/burnin.sh.default $loop ${emmcdev} "${udisk_group[@]}"
								echo ""
								echo "Testing is being performed background..."
								echo ""
								pause
							else
								echo "Your input is illegal, please configure this option again"
								pause 'Press any key to continue...'
							fi 
						else
							pause 'Press any key to return to the main menu...'
						fi
						;;
					*)
						echo "Don't run the pre-defined all-test list"
						pause 'Press any key to return to the main menu...'
						;;
				esac
				;;
			1)
				if [[ ! -e "${app_root_dir}/run/burnin.sh" ]]; then
					echo "There is no test items in self-defined test list, please use the following menu to configure "
					do_test_self_defined
				else
					echo "The following is the test items in self-defined test list" 
					echo "---------------------------------------------------------"
					cat ${app_root_dir}/run/burnin.sh
					echo "---------------------------------------------------------"
					read -p "Run the self-defined test list using current configuration? (Y/N) " res
					case $res in 
						Y|y|"")
							is_wlan0_config=`cat ${app_root_dir}/run/burnin.sh |grep 'wifi'`
							if [[ $is_wlan0_config == "" ]]; then
								is_wlan0_config=disable
							else
								is_wlan0_config=enable
							fi
							is_eth0_config=`cat ${app_root_dir}/run/burnin.sh |grep 'eth0'`
							if [[ $is_eth0_config == "" ]]; then
								is_eth0_config=disable
							else
								is_eth0_config=enable
							fi
							is_eth1_config=`cat ${app_root_dir}/run/burnin.sh |grep 'eth1'`
							if [[ $is_eth1_config == "" ]]; then
								is_eth1_config=disable
							else
								is_eth1_config=enable
							fi
							check_system_config -$is_wlan0_config wlan0 -$is_eth0_config eth0 -$is_eth1_config eth1
							if [[ $is_correct_config == "true" ]]; then
								if [[ -e "./cache.txt" ]]; then
									rm ./cache.txt &>/dev/null
								fi
								touch ./cache.txt &>/dev/null
								chmod 777 ./run/burnin.sh
								sudo ./run/burnin.sh
								echo ""
								echo "Testing is being performed background..."
								echo ""
								pause 
							else
								pause 'Press any key to return to the main menu...'
							fi
							;;
						*)
							echo "Don't run the self-defined test list"
							pause 'Press any key to return to the main menu...'
							;; 
					esac
				fi
				;;
			2)
				if [[ ! -e "${app_root_dir}/run/burnin.sh" ]]; then
					echo "There is no test items in self-defined test list, please use the following menu to configure"
				else
					echo "The following is the test items in self-defined test list currently"
					echo ""
					cat ${app_root_dir}/run/burnin.sh
					echo ""
				fi
				do_test_self_defined
				;;
			3)
				if [[ ! -e "${app_root_dir}/run/burnin.sh" ]]; then
					echo "There is no test items in self-defined test list, please use the following menu to configure"
					do_test_self_defined
				else
					echo "The following is the test items in self-defined test list"
					echo ""
					cat ${app_root_dir}/run/burnin.sh
					echo ""
					pause 'Press any key to continue...'
				fi
				;;
			4)
				rm ./run/burnin.sh &>/dev/null
				echo "All test items in self-defined test list has been cleaned up"
				pause 'Press any key to continue...'
				clear
				;;
			5)
				killall stress-ng &>/dev/null
				ps |grep 'burnin[_/]' |awk '{print $1;}' |xargs kill -9 &>/dev/null
				#ps |grep 'udhcpc -i' |awk '{print $1;}' |xargs kill -9 &>/dev/null
				#ps |grep 'wpa_supplicant' |awk '{print $1;}' |xargs kill -9 &>/dev/null
				killall bonnie++ &>/dev/null
				rm -rf ./Bonnie* &>/dev/null
				echo "The current running test processes has been stopped"
				pause 'Press any key to continue...'
				;;
			6)
				read -p "Enter mac addres (ex: 007D4000A267 ) : " mac
				read -p "Enter SOC number (186 : TX2-NX, 194 : XavierNX, 210 : Nano ) : " soc
				sudo ./bin/eeprom ${soc} ${mac}
				pause 'Press any key to continue...'
				;;
			7)
				read -p "Enter mac addres (ex: D4E5F6123456 ) : " mac
				id=`lspci | grep I210 | awk '{print $1}'`
				if [ -z "$id" ]; then
					echo "Cannot found the I210 ethernet."
					exit 1
				fi
				setpci -s $id COMMAND=0007
				./bin/EepromAccessTool -nic=1 -f=./bin/Dev_Start_I210_Copper_NOMNG_8Mb_A2_3.25_0.03.hex -mac=$mac
				pause 'Press any key to continue...'
				;;
			Q|q|E|e)
				end_test
				echo 7 > /proc/sys/kernel/printk
				exit 0
				;;
			*)
				;;
		esac
	done
}

do_test $1
