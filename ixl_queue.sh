#!/usr/bin/bash
#  Created by Jason Townsend for CONTAP-110409
#  Monitor each queue for changes and core if no changes in threshold 

# 4/11/2024 13:39:30  aff700s-rtp-2a   INFORMATIONAL tape.diagMsg: Tape driver diagnostic messages hwpmc.


# Set how long to sleep
SLEEPTIME=15

# Set the threshold for non-increasing values
THRESHOLD=3

# Initialize associative arrays for previous values and counters
declare -A PREV_VALUES
declare -A COUNTERS

while true; do
    # Get the current rxq values
    declare -A CURRENT_VALUES
    while IFS=: read -r key value; do
        CURRENT_VALUES["$key"]=$value
    done < <(sysctl dev.ixl | grep rx | grep bytes)
    #done < <(cat ixl.out | grep rx | grep bytes)

    # Compare current values to previous values and update counters
    for key in "${!CURRENT_VALUES[@]}"; do
        # Only perform the check and incrementation if the value is not zero
        if (( ${CURRENT_VALUES[$key]} != 0 )); then
            echo "Checking $key: Current Value - ${CURRENT_VALUES[$key]}, Previous Value - ${PREV_VALUES[$key]:-0}"
            if (( ${CURRENT_VALUES[$key]} <= ${PREV_VALUES[$key]:-0} )); then
                ((COUNTERS[$key]++))
                if (( ${COUNTERS[$key]} >= $THRESHOLD )); then
                    ngsh -c "set d -c off;system node autosupport invoke-diagnostic -node local -subsystems nic -message $key"

                    ## Trigger tape.diagMsg with current long_running operations
                    ngsh -c "set d -c off;event generate -node local -message-name tape.diagMsg $key"
                    # Perform sync core action here
                    #sysctl debug.debugger_on_panic=0
                    #sysctl debug.panic=1
                    COUNTERS[$key]=0
                fi
            else
                COUNTERS[$key]=0
            fi
        fi
    done

    # Update previous values
    for key in "${!CURRENT_VALUES[@]}"; do
        PREV_VALUES["$key"]=${CURRENT_VALUES["$key"]}
    done

    # Wait SLEEPTIME seconds
    sleep $SLEEPTIME
done