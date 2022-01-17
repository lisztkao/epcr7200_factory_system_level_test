#! /bin/bash

if [[ -e "./note" ]]; then
	rm note &>/dev/null
fi
touch ./note &>/dev/null

echo "By ctr+c return to the main menu" >> ./note
echo "By ctr+a pause to refresh" >> ./note

read < ./cache.txt ret
watch -t -d "tail -n 2 note $ret "

