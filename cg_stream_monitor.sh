3#!/usr/bin/env bash
#
# ------------------------------------------------------------------
# [Author: August Ritchie]
#		   CG and ZeroStream Connection Monitor Script
#          Alerts when problem client has a bad connection
#          Alerts when CG starts dropping due to backpressure
# ------------------------------------------------------------------
# Instructions
# Place the script on a webserver
# SSH to the SP
# Go to systemshell
# wget <scriptlocation> (example wget http://10.112.73.101/cg_stream_monitor.sh)
# Run with the following command
# sudo bash ./cg_stream_monitor.sh > output.txt

# Set testing vs production variable
TESTING=1

## Set the node name
NODE="nas-cm95-01"

## Filer LIF with Portmapper port
FILER_LIF="10.30.253.60.111"
#FILER_LIF="10.216.29.60.111"

## Client IP
CLIENT_IP="147.141.74.2\.\|147.141.74.3\."
#CLIENT_IP="10.112.73.101"
#CLIENT_IP="10.249.162.19"

## Set ASUP Message
MESSAGE="script_triggered"

## Set how long to sleep
SLEEPTIME=2

## Set counter and threshold for IPv4 drops
INTERESTING_COUNTER="Backpressure IPv4 drop count"
THRESHOLD=10
COUNTER_POSITION="5"

## Testing with static file
if [ "$TESTING" != 1 ]; then
    ## Production command
    declare CG_INFO=($(cgstat -s| grep "$INTERESTING_COUNTER"|awk '{print $'"$COUNTER_POSITION"'}'| sed 's/[^0-9]*//g'))
else
    ## Testing command
    declare CG_INFO=($(cat source/badstream/bad_cg.txt| grep "$INTERESTING_COUNTER"|awk '{print $'"$COUNTER_POSITION"'}'| sed 's/[^0-9]*//g'))
fi


compare_drops() {
    local i=0
    ## Testing with static file
	if [ "$TESTING" != 1 ]; then
	    ## Production command
	    local NEW_CG_INFO=($(cgstat -s| grep "$INTERESTING_COUNTER"|awk '{print $'"$COUNTER_POSITION"'}'| sed 's/[^0-9]*//g'))
	else
	    ## Testing command
	    local NEW_CG_INFO=($(cat source/badstream/bad_cg.txt| grep "$INTERESTING_COUNTER"|awk '{print $'"$COUNTER_POSITION"'}'| sed 's/[^0-9]*//g'))
	fi

    for c in ${NEW_CG_INFO[@]}; do
        DELTA=$(($c-${CG_INFO[$i]}))
        if [ "$DELTA" -gt "$THRESHOLD" ]; then
            echo "Threshold exceeded, Before: ${CG_INFO[$i]} After: $c"
            MESSAGE="CG_ISSUE:$i"
            LOOP=0
        fi
        i=$((i+1))
    done
    CG_INFO=$NEW_CG_INFO
}

zero_streams() {
    ## Testing with static file
	if [ "$TESTING" != 1 ]; then
	    ## Production command
	    declare RESULT=($(netstat -anCETc| grep $CLIENT_IP| grep tcp4))
	else
	    ## Testing command
	    declare RESULT=($(cat source/badstream/netstat_no_bad_stream.txt| grep $CLIENT_IP| grep tcp4))
	fi


	if [ -z "$RESULT" ]; then
		echo "Stream not found"
	else
	    STREAMCOUNT=$((${#RESULT[@]}/22))
	    ZERO_STREAMS_NEW=()
	    i=0
	    while [[ $i -le $(($STREAMCOUNT-1)) ]]; do
	        if [ ${RESULT[$(($((i*22))+17))]} = "0" -a ${RESULT[$(($((i*22))+18))]} = "0" ]; then
	            echo Zero Stream: ${RESULT[$(($((i*22))+7))]}
	            ZERO_STREAMS_NEW+=${RESULT[$(($((i*22))+7))]}
	        fi
	        i=$((i+1))
	    done
	    if [ -n "$ZERO_STREAMS" ]; then
	        for address in $ZERO_STREAMS_NEW; do
                if [[ " ${ZERO_STREAMS[@]} " =~ " ${address} " ]]; then
                    echo Persistent zero stream detected, Client: $address
                    MESSAGE="Problem_Client:$address"
                    LOOP=0
                fi
	        done
	    fi
	    ZERO_STREAMS=$ZERO_STREAMS_NEW
	fi

}

ZERO_STREAMS=()
LOOP="1"
while [ "$LOOP" != "0" ]; do
    sleep $SLEEPTIME
    compare_drops
    zero_streams
    date
done

if [ "$LOOP" != "1" ]; then
    if [ "$TESTING" != 1 ]; then
	    ## Production command
	    ngsh -c "autosupport invoke -node * -message $MESSAGE -type all"
	    ngsh -c "tcpdump stop -node $NODE -port *"
	else
	    ## Testing command
	    echo Autosupport Triggered $MESSAGE
	    echo ngsh -c "autosupport invoke -node * -message $MESSAGE -type all"
	fi
fi
