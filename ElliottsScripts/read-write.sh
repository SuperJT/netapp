#!/bin/bash
################################################################################
# Author: Elliott Ecton [elliott.ecton@netapp.com]
# Description:  This script creates a 40MB file of random data, and then moves it
#               between local and remote storage.  Handy for ensuring read/write
#               ops are present during traces or perfstats
# Version 0.1
# Usage: ./read-write.sh /path/to/remote/ /path/to/local/
# Notes:    Both arguments must have the trailing "/" and must be absolute paths.
#           I ran in to some cases where the '~' was not properly evaluated
################################################################################
THEPATH=$1
THEFILE="NetApp.test"
INFINITE=0
COUNTER=1
locstor=$2

# Function to remove $THEFILE for tidy purposes
cleanup()
{
  if [ -a $THEPATH$THEFILE ]; then
    rm -f $THEPATH$THEFILE
  fi
  if [ -a $locstor$THEFILE ]; then
    rm -f $locstor$THEFILE
  fi
  return 0
}

control_c()
# run if user hits control-c
{
  echo -en "\n*** Control-C detected... Cleaning up... ***\n"
  cleanup
  exit $?
}

# Trap keyboard interrupt (control-c)
trap control_c SIGINT


# Check arguments are there
if [ -z "$1" ]
  then
    echo "Usage: ./read-write.sh /path/to/remote/ /path/to/local/\n***You must include the trailing / for both arguments"
    exit
fi

if [ -z "$2" ]
  then
    echo "Usage: ./read-write.sh /path/to/remote/ /path/to/local/\n***You must include the trailing / for both arguments"
    exit
fi

# Make a random 40MB file for testing
echo "Making a 40MB test file called NetApp.test at $THEPATH..."
dd if=/dev/random of=$THEPATH/NetApp.test bs=4k count=10000


# Begin moving file back and forth
while [  $INFINITE -lt 1 ]; do
    date
    echo "Moving $THEFILE from remote to local storage: Iteration $COUNTER"
    time mv $THEPATH$THEFILE $locstor
    date
    echo "Moving from local to remote storage: Iteration $COUNTER"
    time mv $locstor$THEFILE $THEPATH
    let COUNTER=COUNTER+1
done