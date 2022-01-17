#!/bin/bash
#mount /dev/mmcblk0p2 /usr/advtest/tool/burnin/log
iperf -c 192.168.10.100 -i 5 -t 43200 -d 2>&1 | tee -a /usr/advtest/tool/burnin/log/eth1.log &
sleep 10
iperf -c 198.7.11.100 -i 5 -t 43200 -d 2>&1 | tee -a /usr/advtest/tool/burnin/log/eth2.log &
sleep 10
iperf -c 172.17.7.100 -i 5 -t 43200 -d 2>&1 | tee -a /usr/advtest/tool/burnin/log/eth0.log &


