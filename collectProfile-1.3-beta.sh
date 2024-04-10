#!/usr/bin/env bash
# Data ONTAP Profile collection
# Tim.Kleingeld@netapp.com, NetApp, Jun 2019.
# Version 1.1: Aug 8, 2019 - Detect pmcstat failure and abort quickly and clean up
# Version 1.2: Aug 19, 2019 - Support 9.3+ with kern.bootfile changed, minor cleanups
# Version 1.3: Jun 9, 2020 - Collect user-space profiles as well
# Version 1.3b: Oct 5, 2022 - Support 9.9+ by using unhalted-core-cycles  rather than CPU_CLK_UNHALTED_CORE 
# Based on hwpmc.sh, Author: Elliott.Ecton@netapp.com, Contributor: Jason.Townsend@netapp.com
# Posting to github by Jason.Townsend@netapp.com

sleeptime=60
domain=nwk_exempt
stackdepth=32
doraw=0
basedir=/mroot/etc/log
targetdir=/mroot/etc/crash
clksrc=CPU_CLK_UNHALTED_CORE
if [ `uname -r | awk -F '[^0-9]' '{print $2}'` -ge 9 ]; then
  clksrc=unhalted-core-cycles
fi

while getopts ":hnwseard:t:z:p:P:S:" opt; do
  case ${opt} in
    h )
      echo "Usage: $0 [-hnwsear] [-p procName|-P pid|-d domains] [-t time] [-z stackdepth]"
      echo " -h                      Display this help message."
      echo " -n                      Profile nwk_exempt (default)"
      echo " -w                      Profile wafl_exempt"
      echo " -s                      Profile ssan_exempt"
      echo " -e                      Profile exempt"
      echo " -a                      Profile all domains"
      echo " -d domain,list          Profile other domains. e.g.:"
      echo "    network,protocol,storage,raid,raid_exempt,xor_ex,target,unclassified"
      echo "    kahuna,kahuna_legacy,wafl_mpcleaner,sm_exempt,hostOS,ssan_exempt2"
      echo " -p procName             Profile process (e.g. mgwd) rather than domain"
      echo " -P pid                  Profile process pid rather than domain"
      echo " -t time                 Collect profiles for time seconds (default $sleeptime)"
      echo " -z stackdepth           Stack depth of collected profile (default $stackdepth)"
      echo " -r                      Include raw data in upload"
      echo " -S clock_source         Use alternate clock source (default $clksrc)"
      exit 0
      ;;
   n ) domain=nwk_exempt ;;
   w ) domain=wafl_exempt ;;
   s ) domain=ssan_exempt ;;
   e ) domain=exempt ;;
   a ) domain="" ;;
   r ) doraw=1 ;;
   d ) domain=$OPTARG ;;
   t ) sleeptime=$OPTARG ;;
   z ) stackdepth=$OPTARG ;;
   p ) procName=$OPTARG ;;
   P ) procpid=$OPTARG ;;
   S ) clksrc=$OPTARG ;;
   \? )
     echo "Invalid Option: -$OPTARG" 1>&2
     exit 1
     ;;
  esac
done

if [ ! -z "$procpid" ]; then
   domain=`ps xc "$procpid" | awk '$1 == "'"$procpid"'"{print $5}' `
   if [ -z "$domain" ]; then
      echo "Could not find process associated with pid $procpid - aborting" 1>&2
      exit 1
   fi
elif [ ! -z "$procName" ]; then
   procpid=`ps xc | awk '$5 == "'"$procName"'" { print $1 ; exit }'`
   if [ -z "$procpid" ]; then
      echo "Could not find process with name '$procName' - aborting" 1>&2
      exit 1
   fi
   domain="$procName"
fi

profdir=profile-`uname -n`-$domain-`date +%Y%m%d-%H%M%S`

mkdir $basedir/$profdir
log_file=collectProfile.log

log="$basedir/$profdir/${log_file}"
exec > >(tee -a "$log" )
exec 2> >(tee -a "$log" >&2)

cd $basedir/$profdir

echo "`date`: Run as: $0 " "$@" >> $log
# Remove memory, stack limits, etc
ulimit -d unlimited ; ulimit -s unlimited ; ulimit -m unlimited ; ulimit -v unlimited ; ulimit -l unlimited ; ulimit -n unlimited
echo "`date`: Starting $domain profile collection"
bootfile=`sysctl -n kern.bootfile`
if [ ! -f /boot/kernel/$bootfile ]; then
   # Override the kern.bootfile if the current value isn't valid
   # We set it back at the end...
   sysctl kern.bootfile=/kernel
fi

if [ -z "$procpid" ]; then
   sysctl debug.kgmon.profiled_ontap_domain=$domain

   pmcstat -O /mroot/etc/log/$profdir/sample.$domain.out -n 1000000 -S $clksrc -r /boot/kernel/ &
   pid=$!
else
   pmcstat -O /mroot/etc/log/$profdir/sample.$domain.out -n 1000000 -P $clksrc -r /boot/kernel -t $procpid &
   pid=$!
fi

# Add the trap command here
trap "kill $pid 2> /dev/null" EXIT

sleep 0.2
echo "`date`: Checking to see if pmcstat is running..."
if ps -p $pid ; then
   echo "`date`: Sleeping for $sleeptime seconds"
   sleep $sleeptime
   kill $pid
   ident /boot/modules/maytag.ko | grep Ntap > /mroot/etc/log/$profdir/ident_ntap.txt
   uname -nr > /mroot/etc/log/$profdir/uname.txt
   # Create single directory for links to modules for symbols...
   linkpath=/mroot/home/KOs
   mkdir -p $linkpath
   for ko in /boot/modules/*.ko /boot/kernel/kernel /boot/kernel/*.ko; do
      ln -sf $ko $linkpath
   done

   echo "`date`: Processing profile data - please be patient..."
   pmcstat -R $basedir/$profdir/sample.$domain.out -g -k $linkpath

   echo "`date`: Processing still going..."
   pmcstat -R $basedir/$profdir/sample.$domain.out -k $linkpath -z $stackdepth -G $basedir/$profdir/profile.$domain.txt

   echo "`date`: Done! Generating output file"
   cd $basedir
   chmod -R 777 $profdir
   if [ $doraw = 0 ]; then
      rm -r $profdir/*.out $profdir/$clksrc
   fi
   tar czf $targetdir/$profdir.tgz $profdir
else
   echo "`date`: Could not find pmcstat with pid $pid - is hwpmc supported on this platform?"
fi
echo "`date`: Cleaning up..."
# Delete output directory - move log file out and delete separately as it's still open
mv "$basedir/$profdir/${log_file}" $basedir/${log_file}.tmp
rm -r $basedir/$profdir
rm -f $basedir/${log_file}.tmp
# Clear profiled domain
sysctl debug.kgmon.profiled_ontap_domain=
if [ ! -f /boot/kernel/$bootfile ]; then
   sysctl kern.bootfile=$bootfile
fi
if [ -f $targetdir/$profdir.tgz ] ; then
   echo "`date`: Complete. Please upload $targetdir/$profdir.tgz"
else
   echo "`date`: Failed"
   exit 1
fi
exit 0
#EOF
