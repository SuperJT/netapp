#!/bin/sh
# ------------------------------------------------------------------
# [Author: August Ritchie] 
#		   PORTMAP Connection Monitor Script
#          Alerts when problem client has a portmap connection
# ------------------------------------------------------------------
# Instructions
# Place the script on a webserver
# SSH to the SP
# Go to systemshell
# wget <scriptlocation> (example wget http://10.112.73.101/portmap_monitor.sh)
# Run with the following command
# sudo bash ./portmap_monitor.sh > output.txt

## Set how long to sleep
SLEEPTIME=12

## Filer LIF with Portmapper port
#FILER_LIF="10.30.253.60.111"
FILER_LIF="10.216.29.60.111"

## Client IP
#CLIENT_IP="147.141.74.2"
CLIENT_IP="10.112.73.101"

i="1"
while [ "$i" != "0" ]; do
	## Testing with static file 
	#declare RESULT=($(cat source.txt| grep $FILER_LIF | grep $CLIENT_IP))

	## Production command
	declare RESULT=($(netstat -anCET | grep $FILER_LIF | grep $CLIENT_IP))

	if [ -z "$RESULT" ]; then
		echo "Stream not found"
		sleep $SLEEPTIME
	else
		LOCAL_ADDRESS=${RESULT[6]}
		FOREIGN_ADDRESS=${RESULT[7]}
		CG_ID=${RESULT[11]}
		echo $LOCAL_ADDRESS
		echo $FOREIGN_ADDRESS
		echo $CG_ID
		sleep $SLEEPTIME
		# Check to see if the connection still exists
		# declare RESULT_NEW=($(cat source.txt| grep $FILER_LIF | grep $CLIENT_IP))
		declare RESULT_NEW=($(netstat -anCET | grep $FILER_LIF | grep $CLIENT_IP))
		if [ -z "$RESULT_NEW" ]; then
			echo "Stream no longer seen"
		else
			LOCAL_ADDRESS_NEW=${RESULT_NEW[6]}
			FOREIGN_ADDRESS_NEW=${RESULT_NEW[7]}
			if [ "$FOREIGN_ADDRESS_NEW" != "$FOREIGN_ADDRESS" ]; then
				echo "New Portmap Stream detected from $CLIENT_IP"
			else
				echo "Same portmap connection detected for at least $SLEEPTIME seconds. Problem Detected!"
				# Do something about it
			fi
		fi
	fi
done