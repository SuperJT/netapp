#!/bin/bash
# ------------------------------------------------------------------
# [Author: Jason Townsend] 
#		   Monitor dev.ixl rx queues and core when complete
#          Triggers EMS event tape.diagMsg when seen
# ------------------------------------------------------------------
# Instructions: (easiest way)
# Place the script on a webserver
# SSH to the ONTAP and curl the script into systemshell
# systemshell -node <node> curl <scriptlocation> > long_running.sh 
# 		Example: ::*> systemshell -node nas-cm911-01 -command "curl http://10.119.22.134:8000/long_running.sh > long_running.sh"
# Run with the following command
# systemshell -node <node> -command bash long_running.sh > output.txt &
#		Example: systemshell -node nas-cm911-01 -command bash long_running.sh > n1_output.txt &

## Set how long to sleep
## Wouldn't suggest less than 300 to avoid EMS suppression
SLEEPTIME=300

## Set the threshold for long running ops for $SLEEPTIME seconds duration
## Set to 0 for an EMS event on every sleep duration timer
THRESHOLD=0

## Testing with static File
#declare RESULT=($(cat source.txt| grep long_running | awk '{print $2}' | sed 's/[^0-9]*//g'))

## Production command
declare RESULT=($(ngsh -c 'set d -c off;statistics show -object exec_ctx -counter long_running -raw true -node local' | grep long_running | awk '{print $2}' | sed 's/[^0-9]*//g'))

# We declare the initial values for the first iteration
PREV_RESULT=$RESULT
i="1"

#Loop until we increment putfh_delay_error count by threshold
while [ "$i" != "0" ]; do
    ## Collect the current long_running ops from exec_ctx stats
    ## grep out just the count of the long_running ops for comparison
    
    ## Testing
    #declare RESULT=($(cat source.txt| grep long_running | awk '{print $2}' | sed 's/[^0-9]*//g'))
    
    ## Production command
    declare RESULT=($(ngsh -c 'set d -c off;statistics show -object exec_ctx -counter long_running -raw true -node local' | grep long_running | awk '{print $2}' | sed 's/[^0-9]*//g'))
    
    #Output current values
    date
    echo "Current: $RESULT" 
    echo "Previous: $PREV_RESULT"
    echo "Threshold: $THRESHOLD"
    
    #If the current iteration count and previous iteration were both over the long_running threshold, trigger the action
    if (( $RESULT >= $THRESHOLD && $PREV_RESULT >= $THRESHOLD )); then
        date
		## Uncomment below to break out of the loop after first occurrence
		#i="0"
		
		## Trigger tape.diagMsg with current long_running operations
		ngsh -c "set d -c off;event generate -node local -message-name tape.diagMsg $RESULT"
    fi
    
    PREV_RESULT=$RESULT
    
    #### Wait SLEEPTIME seconds
    sleep $SLEEPTIME
done
