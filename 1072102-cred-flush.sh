#!/bin/bash
# Created by Jason Townsend, Netapp Support, NAS EE

## Goal:
#	Create a script to monitor nblade cred cache and determine if a pending issue is seen.
#	This is specific to bug 1072102
#	
## Set Variables
node="cm2520-ks6-01"
vserver="ftemp"
i=0
## Execute Script

while true; do
	errno=$(sudo ngsh -c "set d -c off;nblade credentials show -vserver $vserver -node $node -unix-user-id 65534" | grep "Info Flags: 17" | awk '{print $3}')
	#echo $errno
	if [ $errno ]; then
		if [ $i == 0 ]; then
			i=1
		else
			#log incident
			echo "Bug 1072102 seen at `date`" >> /mroot/etc/crash/2006778823_logger.log
			echo "issue seen"
			#fix issue
			sudo ngsh -c "set d -c off;nblade credentials flush -vserver $vserver -node $node -unix-user-id 65534"
			i=0
		fi
	fi
	sleep 5
	done
done
