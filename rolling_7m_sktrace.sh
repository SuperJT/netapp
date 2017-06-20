#!/bin/sh
# Run this script from the systemshell on 7-mode filer.
# This will have to be run interactively and cannot be
# invoked from an SSH session.

i="1"
filename="/mroot/etc/sk_roll/sktrace"

while [ $i -ge 0 ]
do
       now=$(date +"%Y-%m-%d %H:%M:%S")
       echo "$filename i=$i $now"
       filename="/mroot/etc/sk_roll/sktrace_$i"

       sudo sysctl sysvar.sktrace.filename="$filename"
       sudo sysctl sysvar.sktrace.NLM_enable=-1
       sudo sysctl sysvar.sktrace.NSM_enable=-1
       sudo sysctl sysvar.sktrace.LMGR_enable=-1 

       if [ $i -ge 201 ]
       then
              temp=$(expr $i - 200) 
              rm -f "/mroot/etc/sk_roll/sktrace_$temp*"
       fi
       sleep 10
       sudo sysctl sysvar.sktrace.dump=1
       i=$(expr $i + 1)
done
