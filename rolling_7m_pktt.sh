#!/bin/bash
# (c) Copyright 2015 NetApp. All rights reserved.
# Author:       Chris Hurley <churley@netapp.com>
# Date:         2015-10-20 
# Description:  Debugging utility to capture additional logs related
# to connections made by an unusual IPv4 address
#
#

FILERETCMOUNT=/filers/christoh-1/vol/vol0/etc 	#full path to the mountpoint of the /etc dir
SAVEPATH=$FILERETCMOUNT/crash/pktt				# Set this to where you want the tgz files
FILER=10.63.98.70								#Either IP address or host name of filer

FILERDATE=$(ssh root@$FILER date)

INTERFACE=e0a									# Which interface to use for the captures (use all for all interfaces)
TARGETHOST=10.63.98.72							# IP address of a target host experiencing the issue
NUMFILES=5										# Number of pktt files to keep
ITERATIONS=96									# Number of iterations (96)
ITERTIME=15										# Time of each iteration in minutes (15)
HASH=`date -d "$FILERDATE" +%F_%H%M%S`			# make a hash that has the current timestamp
START=$(date +%s)								# start time of the script in epoch time
TMPDIR=/crash/tmp_pkttroll_$HASH				# Temporary working dir on filer (relative to /etc)
DEBUGME=true									# Uncomment to set debug logging
LOGFILE=/tmp/tmp_pkttroll_$HASH.log
#
# NOTE: The "traces" directory is off the root volume of the filer NFS mounted on this client so that
#       packet trace and lock status files can be pruned periodically.
#
#------------------------------------------------
#Calculate the total end of the iteration by multiplying
#the number of iterations by the iteration time
#multiply by 60 and add to current epoch

if [ -n "$SAVEPATH" ];then
	if [ ! -d "$SAVEPATH" ]; then					#check and see if the directory we're moving the 
		sudo mkdir -p $SAVEPATH						#tgz file exists.  if not, create it
	fi
fi
sudo mkdir -p $FILERETCMOUNT/$TMPDIR	# Create a directory in etc/crash that we can work from
#sudo touch $LOGFILE		# Create a logfile and change STDOUT and STDERR to log to it
#sudo chmod 777 $LOGFILE
#exec 0<&-				# Close STDIN file descriptor
#exec 1<&-				# Close STDOUT file descriptor
#exec 2<&-				# Close STDERR FD
#exec 1<>$LOGFILE		# Open STDOUT as $LOG_FILE file for read and write.
exec 2>&1				# Redirect STDERR to STDOUT

echo Starting pkttroll.sh at $(date)
#------------------------------------------------
#let's get an ASUP in....
ssh root@$FILER pktt stop all
ssh root@$FILER options autosupport.doit \"Starting pktt collection from date $HASH\"

#------------------------------------------------
#Calculate the total end of the iteration by multiplying
#the number of iterations by the iteration time
#multiply by 60 and add to current epoch
ITERSTART=$(date +%s)
TOTALITER=$(($ITERATIONS*$ITERTIME))
if [ -n "$DEBUGME" ]; then echo Total iteration time $TOTALITER; fi
ITEREND=$(($ITERSTART + $(($TOTALITER*60))))
if [ -n "$DEBUGME" ]; then echo End of script should be $ITEREND; fi
while [ $(date +%s) -lt $ITEREND ]; do
	FILERDATE=$(ssh root@$FILER date)
	if [ "${INTERFACE,,}" = "all" ]; then PKTTFILE=losk; else PKTTFILE=$INTERFACE; fi
	command="ssh root@$FILER pktt start $INTERFACE -d /etc$TMPDIR -m 350 -b 2M"
	if [ "$TARGETHOST" != "" ]; then command="${command} -i $TARGETHOST";fi
	if [ -n "$DEBUGME" ]; then echo Starting pktt on $(date) using $command; fi
	#Start the pktt
	$command
	DELSTR=`ls -t $FILERETCMOUNT/$TMPDIR/$PKTTFILE* | awk "NR>$NUMFILES" |tail -c 20`
	FILENAME=$(date -d "$FILERDATE" +%Y%m%d_%H%M)
	if [ -n "$DEBUGME" ]; then echo File searchstring $FILENAME; fi
	if [ -n "$DELSTR" ]; then
		if [ -n "$SAVEPATH" ]; then
			#tar everything but the most recent
			if [ -n "$DEBUGME" ]; then echo Create new pktt tar file; fi
			sudo find $FILERETCMOUNT/$TMPDIR -name "*.trc" -not -name "*$FILENAME*" -exec basename {} \; | sudo tar cfz $SAVEPATH/pktt_$(date -d "$FILERDATE" +%F_%H%M%S).tgz -C $FILERETCMOUNT/$TMPDIR -T -
			sudo find $FILERETCMOUNT/$TMPDIR -name "*.trc" -not -name "*$FILENAME*" -exec rm {} \;
		else
			#delete the oldest file
			sudo rm $FILERETCMOUNT/$TMPDIR/*$DELSTR; fi
		fi
	#monitor the files (by minute in the filename)
	NUMBIG=0
	until [ $NUMBIG -gt 0 ]; do
		sleep 1
		if [ $(date +%s) -gt $ITEREND ]; then echo Breaking; break; fi
		NUMBIG=`find $FILERETCMOUNT/$TMPDIR -name "*$FILENAME*" -size +999M | wc -l`
	done
	#stop the pktt 
	if [ -n "$DEBUGME" ]; then echo Stopping pktt; fi
	command="ssh root@$FILER pktt stop all"
	$command
done
#------------------------------------------------
if [ -n "$DEBUGME" ]; then echo Ending pktt on $(date); fi
/usr/bin/ssh $FILER "pktt stop all"
/usr/bin/ssh $FILER "options autosupport.doit \"Ending pktt collection from date $HASH\""
if [ -n "$SAVEPATH" ];then
	sudo find $FILERETCMOUNT/$TMPDIR -exec basename {} \; | sudo tar cfz $SAVEPATH/NTAPpktt_$HASH.tgz -C $FILERETCMOUNT/$TMPDIR -T -
	sudo rm -rf $FILERETCMOUNT/$TMPDIR								# Remove the temp working directory in etc/crash
fi
echo Ending pkttroll.sh at $(date)
