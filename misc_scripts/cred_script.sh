#!/usr/bin/env bash
# Authors:	Jason Townsend <jason.townsend@netapp.com
#		Elliott Ecton <elliott.ecton@netapp.com>
#		August Ritchie <august@netapp.com>
#
# Description:	This script montors the nblade credential cache for a duplicate anon cred,
#		if seen, it will migrate the lif and trigger AutoSupports. It waits for 30 continous seconds
#		of the Pending flag before issuing the LIF migration
#		This is specific to NetApp bug 1072102
#		2 files are created
#			/mroot/etc/crash/<caseNumber>-logger.log - when the issue is being hit this populates
#			/mroot/etc/crash/<caseNumber>-logger_nohit.log
#		Place the file in /var/home/diag/cred_script.sh
#		Replace the variables in the variable section of the script
#		Then start the script by issuing the following from ngsh: 
#			systemshell -node cm8080-ks-bot -command "/var/home/diag/cred_script.sh &"
# Version: 2.0


### Variables ###
# Please change these variable for your environment
node="modifyThis"
vserver="modifyThis"
lifname="modifyThis"
remotenode="modifyThis"
casenumber="modifyThis"
# DO NOT CHANGE ANYTHING BELOW HERE!
hitcount=0

## Execute Script
trap "" 1
while [[ "$hitcount" -lt "30" ]]; do
	errno=$(sudo ngsh -c "set d -c off;nblade credentials show -vserver $vserver -node $node -unix-user-id 65534" | grep "Info Flags: 17" | awk '{print $3}' | tr -d '\r')
		if [[ "$errno" == "17" ]]; then
			# Begin 30 second contiguous timer
			let hitcount=$hitcount+1
			# Log that we saw flag 17
			echo "`date`: Pending flag seen. Count: $hitcount" >> /mroot/etc/crash/$casenumber-logger.log
			sleep 1
		else
			# Reset hit counter	
			hitcount=0
			echo "`date`: Pending flag not seen" >> /mroot/etc/crash/$casenumber-logger_nohit.log
			sleep 5
		fi
done

# Execute action plan since issue has been seen for ~30 seconds
if [[ "$hitcount" > "29" ]]; then
	#Log that we hit 30+ seconds of pending flag against the cred
	echo "`date`: 30+ seconds of continous pending flag. Count: $hitcount" >> /mroot/etc/crash/$casenumber-logger.log
	
	#### LIF Migration ####
	#Log that we're migrating our access LIF to the remote node 
	echo "`date`: migrating LIF $lifname to $remotenode" >> /mroot/etc/crash/$casenumber-logger.log
	#Now perform the migration
	migrate=$(sudo ngsh -c "net int migrate -vserver $vserver -lif $lifname -destination-node $remotenode")
	echo $migrate >> /mroot/etc/crash/$casenumber-logger.log
	
	### ASUP ###
	#Log that we're triggering an ASUP
	echo "`date`: Triggering ASUP" >> /mroot/etc/crash/$casenumber-logger.log
	#Now trigger the ASUP
	asup=$(sudo ngsh -c "autosupport invoke -node * -type all -message CRED_ISSUE_SEEN")
	echo $asup >> /mroot/etc/crash/$casenumber-logger.log
fi
