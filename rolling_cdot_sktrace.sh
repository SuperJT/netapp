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
#  nohup ./logroll.sh &
#
#
# written by:  Chris Hurley
# christoh@netapp.com

MGWDLOG=true									# need to set debug to mgwd log and roll it
SECDLOG=true									# need to set debug to secd log and roll it
SKTLOG=true										# need to set debug to sktlog log and roll it
SAVEPATH=/clus/vserver/volume/logroll			# Set this to where you want the tgz files
ITERATIONS=96									# Number of iterations (96)
ITERTIME=15										# Time of each iteration in minutes (15)
HASH=`date +%F_%H%M%S`							# make a hash that has the current timestamp
START=$(date +%s)								# start time of the script in epoch time
TMPDIR=/mroot/etc/crash/tmp_logroll_$HASH		# Temporary working dir
DEBUGME=true									# Uncomment to set debug logging
LOGFILE=$TMPDIR/tmp_logroll_$HASH.log			# THE log file

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

echo Starting logroll.sh at $(date)
# Copy the sktlogd files to something based on the date and then "clear" the sktlogd.log file
#sudo cp /mroot/etc/log/mlog/sktlogd.log /mroot/etc/log/mlog/sktlogd.log.$(date +%F_%H%M%S.log)
#sudo cat /dev/null >/mroot/etc/log/mlog/sktlogd.log
#sudo cp /mroot/etc/log/mlog/mgwd.log /mroot/etc/log/mlog/mgwd.log.$(date +%F_%H%M%S.log)
#sudo cat /dev/null >/mroot/etc/log/mlog/mgwd.log
sudo cp /mroot/etc/log/mlog/secd.log /mroot/etc/log/mlog/secd.log.$(date +%F_%H%M%S.log)
sudo cat /dev/null >/mroot/etc/log/mlog/secd.log
	
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
ngsh -c "set diag -c off;diag secd trace set -trace-all yes -node $HOSTNAME"
#
#	End of the secd variables
#------------------------------------------------

#------------------------------------------------#
#	Add any commands that need to gather info
#	from the beginning of the capture
#
if [ -n "$DEBUGME" ]; then echo Save nblade counters; fi
sudo sysctl sysvar.nblade | sudo tee $TMPDIR/nblade_counters_`date +%F_%H%M%S`.txt > /dev/null
if [ -n "$DEBUGME" ]; then echo Send ASUP through ngsh; fi
ngsh -c "autosupport invoke * all -m \"Starting data collection from date $HASH\""
#
#------------------------------------------------
while [ $ITERATIONS -gt 0 ]; do
	#wait for the iteration time and copy the sktlogd files to a working dir then "clear" 
	#the sktlogd.log file in mlog
	if [ -n "$DEBUGME" ]; then echo Iteration: $ITERATIONS on $(date); fi
	sleep $(($ITERTIME*60))
	sudo sysctl sysvar.nblade | sudo tee $TMPDIR/nblade_counters_`date +%F_%H%M%S`.txt > /dev/null
	#sudo cp -v /mroot/etc/log/mlog/sktlogd.log $TMPDIR/sktlogd.log.$ITERATIONS
	#sudo cp -v /mroot/etc/log/mlog/mgwd.log $TMPDIR/mgwd.log.$ITERATIONS
	sudo cp -v /mroot/etc/log/mlog/secd.log $TMPDIR/secd.log.$ITERATIONS
	if [ -n "$DEBUGME" ]; then echo Moving files; fi
	#sudo find /mroot/etc/log/mlog -name "sktlogd.log.*" -cmin -$((($(date +%s) - $START)/60)) -mmin +1 -exec mv {} $TMPDIR \;
	#sudo find /mroot/etc/log/mlog -name "mgwd.log.*" -cmin -$((($(date +%s) - $START)/60)) -mmin +1 -exec mv {} $TMPDIR \;
	sudo find /mroot/etc/log/mlog -name "secd.log.*" -cmin -$((($(date +%s) - $START)/60)) -mmin +1 -exec mv {} $TMPDIR \;
	#sudo cat /dev/null >/mroot/etc/log/mlog/sktlogd.log
	#sudo cat /dev/null >/mroot/etc/log/mlog/mgwd.log
	sudo cat /dev/null >/mroot/etc/log/mlog/secd.log
	if [ -n "$DEBUGME" ]; then echo Files copied to $TMPDIR; fi
	#see if there already is a tgz file that matches this hour.  If there is, then add the sktlog from the working
	#directory to the tar file.  If not create a new tarfile from the sktlog in the working directory.
	#SKTARFILE=`find $SAVEPATH/ -name sktlogd_$(date +%F_%H)*`
	#MGWDTARFILE=`find $SAVEPATH/ -name mgwd_$(date +%F_%H)*`
	SECDTARFILE=`find $SAVEPATH/ -name secd_$(date +%F_%H)*`
	
	if [ -z $SKTARFILE ]; then
		if [ -n "$DEBUGME" ]; then echo Create new sktlogd tar file; fi
		#sudo find $TMPDIR -name 'sktlogd.*' -exec basename {} \; | sudo tar cfz $SAVEPATH/sktlogd_$(date +%F_%H%M%S).tgz -C $TMPDIR -T -
	else
		if [ -n "$DEBUGME" ]; then echo Append $SKTARFILE; fi
		sudo gunzip $SKTARFILE
		sudo rm -f $SKTARFILE
		sudo find $TMPDIR -name 'sktlogd.*' -exec basename {} \; | sudo tar rf ${SKTARFILE/%gz/ar} -C $TMPDIR -T -
		sudo gzip ${SKTARFILE/%gz/ar}
		sudo mv -f ${SKTARFILE/%gz/ar}.gz $SKTARFILE
	fi
	
	if [ -z $MGWDTARFILE ]; then
		if [ -n "$DEBUGME" ]; then echo Create new mgwd tar file; fi
		#sudo find $TMPDIR -name 'mgwd.*' -exec basename {} \; | sudo tar cfz $SAVEPATH/mgwd_$(date +%F_%H%M%S).tgz -C $TMPDIR -T -
	else
		if [ -n "$DEBUGME" ]; then echo Append $MGWDTARFILE; fi
		sudo gunzip $MGWDTARFILE
		sudo rm -f $MGWDTARFILE
		sudo find $TMPDIR -name 'mgwd.*' -exec basename {} \; | sudo tar rf ${MGWDTARFILE/%gz/ar} -C $TMPDIR -T -
		sudo gzip ${MGWDTARFILE/%gz/ar}
		sudo mv -f ${MGWDTARFILE/%gz/ar}.gz $MGWDTARFILE
	fi
	
	if [ -z $SECDTARFILE ]; then
		if [ -n "$DEBUGME" ]; then echo Create new secd tar file; fi
		sudo find $TMPDIR -name 'secd.*' -exec basename {} \; | sudo tar cfz $SAVEPATH/secd_$(date +%F_%H%M%S).tgz -C $TMPDIR -T -
	else
		if [ -n "$DEBUGME" ]; then echo Append $SECDTARFILE; fi
		sudo gunzip $SECDTARFILE
		sudo rm -f $SECDTARFILE
		sudo find $TMPDIR -name 'secd.*' -exec basename {} \; | sudo tar rf ${SECDTARFILE/%gz/ar} -C $TMPDIR -T -
		sudo gzip ${SECDTARFILE/%gz/ar}
		sudo mv -f ${SECDTARFILE/%gz/ar}.gz $SECDTARFILE
	fi
	
	#sudo rm -f $TMPDIR/sktlogd.*
	#sudo rm -f $TMPDIR/mgwd.*
	sudo rm -f $TMPDIR/secd.*
	
	let ITERATIONS-=1
done
#------------------------------------------------
sudo sysctl sysvar.nblade | sudo tee $TMPDIR/nblade_counters_`date +%F_%H%M%S`.txt > /dev/null
ngsh -c "autosupport invoke * all -m \"Ending data collection from date $HASH\""
sudo find $TMPDIR -exec basename {} \; | sudo tar cfz $SAVEPATH/NTAPcollect_$HASH.tgz -C $TMPDIR -T -

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
	ngsh -c "set diag -c off;diag secd trace set -trace-all no -node $HOSTNAME"
#
#	End of the secd variables
#------------------------------------------------

sudo rm -rf $TMPDIR								# Remove the temp working directory in etc/crash
echo Ending logroll.sh at $(date)