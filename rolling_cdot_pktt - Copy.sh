#!/usr/bin/bash
# (c) Copyright 2015 NetApp. All rights reserved.
# Author:       Chris Hurley <churley@netapp.com>
# Date:         2015-10-20 
# Description:  Debugging utility to capture additional logs related
# to connections made by an unusual IPv4 address
#
# WARNING: this utility should only be used under the guidance of NetApp
# support personnel. If used for a commonly used IP, the /tmp partition
# may fill up.
#
# Run this script from the systemshell on cDOT filer.
# This will have to be run interactively and cannot be
# invoked from an SSH session.  
# ***************CAUTION*************
# This can quickly fill up the node's root volume!!!!!
# Recommend that there is a separate volume set up to 
# accept the tars of the sktlogs!!!
#
# **************MORE CAUTIONS!!!!!!!!!!!!
#
#  IF YOU CTRL-C THIS SCRIPT, YOU WILL NEED TO CLEAN UP
#  ALL THE THINGS THIS SCRIPT DOES!!!!!!!!!!!!!!!!!!!!!
#
#
#
# In order to run this script properly in systemshell use nohup!!!!
#
#  nohup ./pkttroll.sh &
#


SAVEPATH=/clus/vserver/volume/pktt				# Set this to where you want the tgz files
ITERATIONS=96									# Number of iterations (96)
ITERTIME=15										# Time of each iteration in minutes (15)
NUMFILES=5										# Number of pktt files to keep
HASH=`date +%F_%H%M%S`							# make a hash that has the current timestamp
START=$(date +%s)								# start time of the script in epoch time
TMPDIR=/mroot/etc/crash/tmp_pkttroll_$HASH		# Temporary working dir
DEBUGME=true									# Uncomment to set debug logging
LOGFILE=$TMPDIR/tmp_pkttroll_$HASH.log

if [ -n "$SAVEPATH" ];then
	if [ ! -d "$SAVEPATH" ]; then					#check and see if the directory we're moving the 
		sudo mkdir -p $SAVEPATH						#tgz file exists.  if not, create it
	fi
fi

sudo mkdir -p $TMPDIR	# Create a directory in etc/crash that we can work from
sudo touch $LOGFILE		# Create a logfile and change STDOUT and STDERR to log to it
sudo chmod 777 $LOGFILE
exec 0<&-				# Close STDIN file descriptor
exec 1<&-				# Close STDOUT file descriptor
exec 2<&-				# Close STDERR FD
exec 1<>$LOGFILE		# Open STDOUT as $LOG_FILE file for read and write.
exec 2>&1				# Redirect STDERR to STDOUT

echo Starting pkttroll.sh at $(date)
ngsh -c "autosupport invoke * all -m \"Starting pktt collection from date $HASH\""
#
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
	if [ -n "$DEBUGME" ]; then echo Starting pktt on $(date); fi
	#Start the pktt
	TMPPKTTDIR=$(echo "$TMPDIR" | sed 's/\/mroot//')
	ngsh -c "node run local pktt start all -d ${TMPPKTTDIR} -m 350 -b 2M"
	#Check for NUMFILES number of trc files
	#if there's more than NUMFILES, delete the oldest
	DELSTR=`ls -t $TMPDIR/losk* | awk "NR>$NUMFILES" |tail -c 20`
	FILENAME=$(date +%Y%m%d_%H%M)
	if [ -n "$DEBUGME" ]; then echo File searchstring $FILENAME; fi
	if [ -n "$DELSTR" ]; then
		if [ -n "$SAVEPATH" ]; then
			#tar everything but the most recent
			if [ -n "$DEBUGME" ]; then echo Create new pktt tar file; fi
			sudo find $TMPDIR -name "*.trc" -not -name "*$FILENAME*" -exec basename {} \; | sudo tar cfz $SAVEPATH/pktt_$(date +%F_%H%M%S).tgz -C $TMPDIR -T -
			sudo find $TMPDIR -name "*.trc" -not -name "*$FILENAME*" -exec rm {} \;
		else
			#delete the oldest file
			sudo rm $TMPDIR/*$DELSTR; fi
		fi
	#monitor the files (by minute in the filename)
	NUMBIG=0
	until [ $NUMBIG -gt 0 ]; do
		sleep 1
		if [ $(date +%s) -gt $ITEREND ]; then echo Breaking; break; fi
		NUMBIG=`find $TMPDIR -name "*$FILENAME*" -size +999M | wc -l`
	done
	#stop the pktt 
	if [ -n "$DEBUGME" ]; then echo Stopping pktt; fi
	ngsh -c "node run local pktt stop all"
done
#------------------------------------------------
if [ -n "$DEBUGME" ]; then echo Ending pktt on $(date); fi
ngsh -c "node run local pktt stop all"
ngsh -c "autosupport invoke * all -m \"Ending pktt collection from date $HASH\""
if [ -n "$SAVEPATH" ];then
	sudo find $TMPDIR -exec basename {} \; | sudo tar cfz $SAVEPATH/NTAPpktt_$HASH.tgz -C $TMPDIR -T -
	sudo rm -rf $TMPDIR								# Remove the temp working directory in etc/crash
fi
echo Ending pkttroll.sh at $(date)