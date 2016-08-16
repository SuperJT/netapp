#!/usr/bin/bash
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
#  nohup ./lacproll.sh &
#
#
# written by:  Chris Hurley
# christoh@netapp.com

MGWDLOG=true									# need to set debug to mgwd log and roll it
SECDLOG=true									# need to set debug to secd log and roll it
SKTLOG=true										# need to set debug to sktlog log and roll it
CUSTOM=true										# you can put custom commands in here to roll those.
SAVEPATH=/clus/vserver/volume/lacproll			# Set this to where you want the tgz files
ITERATIONS=288									# Number of iterations (288)
ITERTIME=5										# Time of each iteration in minutes (5)
HASH=`date +%F_%H%M%S`							# make a hash that has the current timestamp
START=$(date +%s)								# start time of the script in epoch time
TMPDIR=/mroot/etc/crash/tmp_lacproll_$HASH		# Temporary working dir
DEBUGME=true									# Uncomment to set debug logging
LOGFILE=$TMPDIR/tmp_lacproll_$HASH.log			# THE log file

if [ ! -d "$SAVEPATH" ]; then					#check and see if the directory we're moving the 
	sudo mkdir -p $SAVEPATH						#tgz file exists.  if not, create it
fi


##################################################################################
##################################################################################
#
#  DO NOT MODIFY ANYTHING BELOW THIS LINE!!!!!!!!!!!!!!!!
#
###################################################################################
###################################################################################
sudo mkdir -p $TMPDIR	# Create a directory in etc/crash that we can work from
sudo touch $LOGFILE		# Create a logfile and change STDOUT and STDERR to log to it
sudo chmod 777 $LOGFILE
exec 0<&-				# Close STDIN file descriptor
exec 1<&-				# Close STDOUT file descriptor
exec 2<&-				# Close STDERR FD
exec 1<>$LOGFILE		# Open STDOUT as $LOG_FILE file for read and write.
exec 2>&1				# Redirect STDERR to STDOUT

echo Starting lacproll.sh at $(date)
# Copy the sktlogd files to something based on the date and then "clear" the sktlogd.log file
#sudo cp /mroot/etc/log/mlog/sktlogd.log /mroot/etc/log/mlog/sktlogd.log.$(date +%F_%H%M%S.log)
#sudo cat /dev/null >/mroot/etc/log/mlog/sktlogd.log
#sudo cp /mroot/etc/log/mlog/mgwd.log /mroot/etc/log/mlog/mgwd.log.$(date +%F_%H%M%S.log)
#sudo cat /dev/null >/mroot/etc/log/mlog/mgwd.log
#sudo cp /mroot/etc/log/mlog/secd.log /mroot/etc/log/mlog/secd.log.$(date +%F_%H%M%S.log)
#sudo cat /dev/null >/mroot/etc/log/mlog/secd.log
sudo cp /mroot/etc/log/lacp_log /mroot/etc/log/lacp_log.$(date +%F_%H%M%S.log)
sudo cat /dev/null >/mroot/etc/log/lacp_log
	
#------------------------------------------------#
#	Here is where we add the variables that need
#	set on the filer to capture the data
#------------------------------------------------#
#
#	Set sktrace variables
#
#sudo sysctl sysvar.sktrace.AccessCacheDebug_enable=-1
#sudo sysctl sysvar.sktrace.NfsDebug_enable=63
#sudo sysctl sysvar.sktrace.MntDebug_enable=-1
sudo sysctl sysvar.dbg.lacp=1
#
#	End of the sktrace variables
#------------------------------------------------
#
#	Set mgwd variables
#
if [ -n "$DEBUGME" ]; then echo Set mgwd debug through ngsh; fi
#ngsh -c "set diag -c off;logger mgwd log modify -module mgwd::exports -level debug -node $HOSTNAME"
#ngsh -c "set diag -c off;logger mgwd log modify -module mgwd::exports -level debug"
#
#	End of the mgwd variables
#------------------------------------------------
#
#	Set secd variables
#
if [ -n "$DEBUGME" ]; then echo Set secd debug through ngsh; fi
#ngsh -c "set diag -c off;diag secd trace set -trace-all yes -node $HOSTNAME"
#
#	End of the secd variables
#------------------------------------------------

#------------------------------------------------#
#	Add any commands that need to gather info
#	from the beginning of the capture
#
if [ -n "$DEBUGME" ]; then echo Save nblade counters; fi
sudo sysctl sysvar.nblade | sudo tee $TMPDIR/nblade_counters_`date +%F_%H%M%S`.txt > /dev/null
if [ -n "$DEBUGME" ]; then echo Clearing ifstat counters; fi
ngsh -c "run local ifstat -z e2a"
ngsh -c "run local ifstat -z e2b"
if [ -n "$DEBUGME" ]; then echo Dumping rastrace; fi
ngsh -c "run local \"priv set diag;rastrace dump -m 14\""
sleep 2
mv -f /mroot/etc/log/rastrace/* $TMPDIR
if [ -n "$DEBUGME" ]; then echo Send ASUP through ngsh; fi
ngsh -c "autosupport invoke * all -m \"Starting data collection from date $HASH\""
#
#------------------------------------------------
while [ $ITERATIONS -gt 0 ]; do
	#wait for the iteration time and copy the sktlogd files to a working dir then "clear" 
	#the sktlogd.log file in mlog
	if [ -n "$DEBUGME" ]; then echo Iteration: $ITERATIONS on $(date); fi
	#------------------------------------------------#	start pktt
	if [ -n "$DEBUGME" ]; then echo Starting pktt on $(date); fi
	TMPPKTTDIR=$(echo "$TMPDIR" | sed 's/\/mroot//')
	ngsh -c "node run local \"pktt start a0a -d ${TMPPKTTDIR} -m 130 -b 2M\""
	sleep $(($ITERTIME*60))
	#sudo sysctl sysvar.nblade | sudo tee $TMPDIR/nblade_counters_`date +%F_%H%M%S`.txt > /dev/null
	#sudo cp -v /mroot/etc/log/mlog/sktlogd.log $TMPDIR/sktlogd.log.$ITERATIONS
	#sudo cp -v /mroot/etc/log/mlog/mgwd.log $TMPDIR/mgwd.log.$ITERATIONS
	#sudo cp -v /mroot/etc/log/mlog/secd.log $TMPDIR/secd.log.$ITERATIONS
	if [ -n "$DEBUGME" ]; then echo Running misc commands on $(date); fi
	ngsh -c "run local \"priv set diag;rtag -t mbuf\"" | sudo tee $TMPDIR/rtag_`date +%F_%H%M%S`.txt > /dev/null
	ngsh -c "run local \"priv set diag;ifinfo -a\"" | sudo tee $TMPDIR/ifinfo_`date +%F_%H%M%S`.txt > /dev/null
	ngsh -c "run local \"priv set diag;mbstat\"" | sudo tee $TMPDIR/mbstat_`date +%F_%H%M%S`.txt > /dev/null
	ngsh -c "run local \"priv set diag;ifstat -a\"" | sudo tee $TMPDIR/ifstat_`date +%F_%H%M%S`.txt > /dev/null
	ngsh -c "run local \"priv set diag;ifgrp status\"" | sudo tee $TMPDIR/ifgrp_`date +%F_%H%M%S`.txt > /dev/null
	if [ -n "$DEBUGME" ]; then echo Stopping pktt; fi
	ngsh -c "node run local pktt stop all"
	if [ -n "$DEBUGME" ]; then echo Moving files; fi
	#sudo find /mroot/etc/log/mlog -name "sktlogd.log.*" -cmin -$((($(date +%s) - $START)/60)) -mmin +1 -exec mv {} $TMPDIR \;                # put cmin in here to make sure that it was created since the script was started
	#sudo find /mroot/etc/log/mlog -name "mgwd.log.*" -cmin -$((($(date +%s) - $START)/60)) -mmin +1 -exec mv {} $TMPDIR \;                   # the mmin calc is to make sure the file was modified in the last minute
	#sudo find /mroot/etc/log/mlog -name "secd.log.*" -cmin -$((($(date +%s) - $START)/60)) -mmin +1 -exec mv {} $TMPDIR \;
	sudo find /mroot/etc/log -name "lacp_lo*" -exec cp {} $TMPDIR/lacp_log.$(date +%F_%H%M%S.log) \;											#dont need mmin or cmin because there are only 2 lacp_log files.  current and bak
	#sudo cat /dev/null >/mroot/etc/log/mlog/sktlogd.log
	#sudo cat /dev/null >/mroot/etc/log/mlog/mgwd.log
	#sudo cat /dev/null >/mroot/etc/log/mlog/secd.log
	sudo cat /dev/null >/mroot/etc/log/lacp_log
	if [ -n "$DEBUGME" ]; then echo Files copied to $TMPDIR; fi
	#see if there already is a tgz file that matches this hour.  If there is, then add the sktlog from the working
	#directory to the tar file.  If not create a new tarfile from the sktlog in the working directory.
	#SKTGZFILE=`find $SAVEPATH/ -name sktlogd_$(date +%F_%H)*`
	#MGWDTGZFILE=`find $SAVEPATH/ -name mgwd_$(date +%F_%H)*`
	#SECDTGZFILE=`find $SAVEPATH/ -name secd_$(date +%F_%H)*`
	LACPTGZFILE=`find $SAVEPATH/ -name lacp_$(date +%F_%H)*`
	PKTTTGZFILE=`find $SAVEPATH/ -name pktt_$(date +%F_%H)*`
	
	if [ -z $SKTGZFILE ]; then
		if [ -n "$DEBUGME" ]; then echo Create new sktlogd tar file; fi
		#sudo find $TMPDIR -name 'sktlogd.*' -exec basename {} \; | sudo tar cfz $SAVEPATH/sktlogd_$(date +%F_%H%M%S).tgz -C $TMPDIR -T -
	else
		if [ -n "$DEBUGME" ]; then echo Append $SKTGZFILE; fi
		sudo gunzip $SKTGZFILE
		sudo rm -f $SKTGZFILE
		SKTARFILE=$(echo "$SKTGZFILE" | sed 's/tgz/tar/')
		sudo find $TMPDIR -name 'sktlogd.*' -exec basename {} \; | sudo tar rf $SKTARFILE -C $TMPDIR -T -
		sudo gzip $SKTARFILE
		sudo mv -f $SKTARFILE.gz $SKTGZFILE
	fi
	
	if [ -z $MGWDTGZFILE ]; then
		if [ -n "$DEBUGME" ]; then echo Create new mgwd tar file; fi
		#sudo find $TMPDIR -name 'mgwd.*' -exec basename {} \; | sudo tar cfz $SAVEPATH/mgwd_$(date +%F_%H%M%S).tgz -C $TMPDIR -T -
	else
		if [ -n "$DEBUGME" ]; then echo Append $MGWDTGZFILE; fi
		sudo gunzip $MGWDTGZFILE
		sudo rm -f $MGWDTGZFILE
		MGWDTARFILE=$(echo "$MGWDTGZFILE" | sed 's/tgz/tar/')
		sudo find $TMPDIR -name 'mgwd.*' -exec basename {} \; | sudo tar rf $MGWDTARFILE -C $TMPDIR -T -
		sudo gzip $MGWDTARFILE
		sudo mv -f $MGWDTARFILE.gz $MGWDTGZFILE
	fi
	
	if [ -z $SECDTGZFILE ]; then
		if [ -n "$DEBUGME" ]; then echo Create new secd tar file; fi
		#sudo find $TMPDIR -name 'secd.*' -exec basename {} \; | sudo tar cfz $SAVEPATH/secd_$(date +%F_%H%M%S).tgz -C $TMPDIR -T -
	else
		if [ -n "$DEBUGME" ]; then echo Append $SECDTGZFILE; fi
		sudo gunzip $SECDTGZFILE
		sudo rm -f $SECDTGZFILE
		SECDTARFILE=$(echo "$SECDTGZFILE" | sed 's/tgz/tar/')
		sudo find $TMPDIR -name 'secd.*' -exec basename {} \; | sudo tar rf $SECDTARFILE -C $TMPDIR -T -
		sudo gzip $SECDTARFILE
		sudo mv -f $SECDTARFILE.gz $SECDTGZFILE
	fi
	
	if [ -z $LACPTGZFILE ]; then
		if [ -n "$DEBUGME" ]; then echo Create new lacp tar file; fi
		sudo find $TMPDIR -name 'lacp_lo*' -exec basename {} \; | sudo tar cfz $SAVEPATH/lacp_$(date +%F_%H%M%S).tgz -C $TMPDIR -T -
	else
		if [ -n "$DEBUGME" ]; then echo Append $LACPTGZFILE; fi
		sudo gunzip $LACPTGZFILE
		sudo rm -f $LACPTGZFILE
		LACPTARFILE=$(echo "$LACPTGZFILE" | sed 's/tgz/tar/')
		sudo find $TMPDIR -name 'lacp_lo*' -exec basename {} \; | sudo tar rf $LACPTARFILE -C $TMPDIR -T -
		sudo gzip $LACPTARFILE
		sudo mv -f $LACPTARFILE.gz $LACPTGZFILE
	fi
	
	if [ -z $PKTTTGZFILE ]; then
		if [ -n "$DEBUGME" ]; then echo Create new pktt tar file; fi
		sudo find $TMPDIR -name '*.trc' -exec basename {} \; | sudo tar cfz $SAVEPATH/pktt_$(date +%F_%H%M%S).tgz -C $TMPDIR -T -
	else
		if [ -n "$DEBUGME" ]; then echo Append $PKTTTGZFILE; fi
		sudo gunzip $PKTTTGZFILE
		sudo rm -f $PKTTTGZFILE
		PKTTTARFILE=$(echo "$PKTTTGZFILE" | sed 's/tgz/tar/')
		sudo find $TMPDIR -name '*.trc*' -exec basename {} \; | sudo tar rf $PKTTTARFILE -C $TMPDIR -T -
		sudo gzip $PKTTTARFILE
		sudo mv -f $PKTTTARFILE.gz $PKTTTGZFILE
	fi
	
	#sudo rm -f $TMPDIR/sktlogd.*
	#sudo rm -f $TMPDIR/mgwd.*
	#sudo rm -f $TMPDIR/secd.*
	sudo rm -f $TMPDIR/lacp_lo*
	sudo rm -f $TMPDIR/*.trc
	
	let ITERATIONS-=1
done
#------------------------------------------------
if [ -n "$DEBUGME" ]; then echo Done with the iterations.  Moving to final; fi
if [ -n "$DEBUGME" ]; then echo Save nblade counters; fi
sudo sysctl sysvar.nblade | sudo tee $TMPDIR/nblade_counters_`date +%F_%H%M%S`.txt > /dev/null
if [ -n "$DEBUGME" ]; then echo Dumping rastrace; fi
ngsh -c "run local \"priv set diag;rastrace dump -m 14\""
sleep 2
mv -f /mroot/etc/log/rastrace/* $TMPDIR
ngsh -c "autosupport invoke * all -m \"Ending data collection from date $HASH\""

#------------------------------------------------#
#	Here is where we clear the variables that were
#	set above in the script
#------------------------------------------------#
#
#	Clear sktrace variables
#
#sudo sysctl sysvar.sktrace.AccessCacheDebug_enable=0
#sudo sysctl sysvar.sktrace.MntDebug_enable=0
#sudo sysctl sysvar.sktrace.NfsDebug_enable=0 
#sudo sysctl sysvar.sktrace.OncRpcDebug=0
#sudo sysctl sysvar.sktrace.Nfs3ProcDebug_enable=0
#sudo sysctl sysvar.sktrace.NfsCredStoreDebug_enable=0
#sudo sysctl sysvar.sktrace.NfsPathResolutionDebug_enable=0
sudo sysctl sysvar.dbg.lacp=6
#
#	End of the sktrace variables
#------------------------------------------------
#
#	Clear mgwd variables
#
	#ngsh -c "set diag -c off;logger mgwd log modify -module mgwd::exports -level err -node $HOSTNAME"
#
#	End of the mgwd variables
#------------------------------------------------
#
#	Clear secd variables
#
	#ngsh -c "set diag -c off;diag secd trace set -trace-all no -node $HOSTNAME"
#
#	End of the secd variables
#------------------------------------------------
echo Ending lacproll.sh at $(date)
exec 0<&-				# Close STDIN file descriptor
exec 1<&-				# Close STDOUT file descriptor
exec 2<&-				# Close STDERR FD
sudo tar cfz $SAVEPATH/NTAPcollect_$HASH.tgz -C $TMPDIR .
sudo rm -rf $TMPDIR								# Remove the temp working directory in etc/crash