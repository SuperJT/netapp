#!/bin/bash
# Created by Jason Townsend, Netapp Support, NAS EE

## Goal:
#	Create a script to monitor sktrace.log and stop pktt if rt=4040, 4039, 4041 is seen.
#	
#	
## Set Variables

## Execute Script

tail -Fn0 /mroot/etc/log/mlog/sktrace.log | \
while read line ; do
	echo "$line" | grep "rt=4040"
	if [ $? = 0 ]
	then
		sleep 10
		sudo ngsh -n "pktt stop all"
		sudo ngsh -c "autosupport invoke -node * -type all -message STALE_STATEID_CAUGHT"
	fi
done
