#!/bin/bash
# ------------------------------------------------------------------
# [Author: Jason Townsend] 
#		   Monitor ems.log for ipfw.ReachedMaxStates lines.  
#          Once this finds the event, trigger cleanup to tar files,
#          generate an EMS event, and invoke AutoSupport.
# ------------------------------------------------------------------

# Directory where the output files will be saved
output_dir="/mroot/etc/log/mlog"
ems_log="/mroot/etc/log/ems"
emsMatch="ipfw.ReachedMaxStates"

# Ensure the output directory exists
mkdir -p "$output_dir"

# Function to execute the command and save the output
generate_ipfw_output() {
    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local output_file="$output_dir/ipfw_dyn_list_$timestamp.txt"
    sudo ipfw -d list > "$output_file"
    count_and_sort_ip_pairs "$output_file"
}

# Function to count and sort IP pairs from a given file and append the summary to the file
count_and_sort_ip_pairs() {
    local file="$1"
    awk '
    {
        # Extract the IP pairs from the log lines
        if (match($0, /([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) [0-9]+ <-> ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/, arr)) {
            ip_pair = arr[1] " <-> " arr[2]
            ip_count[ip_pair]++
        }
    }
    END {
        # Print the count of each IP pair
        for (ip in ip_count) {
            print ip_count[ip], ip
        }
    }
    ' "$file" | sort -nr | tee -a "$file"
}

# Function to clean up generated files by tarring them
cleanup() {
    echo "Tarring up generated files..."
    tar_file="/mroot/etc/log/mlog/ipfw_dyn_list_$(date +"%Y%m%d-%H%M%S").tar.gz"
    recent_files=$(find "$output_dir" -type f -name "ipfw_dyn_list_*.txt" -mmin -10)
    if [ -n "$recent_files" ]; then
        tar -czf "$tar_file" $recent_files
        echo "Files tarred to $tar_file"
    else
        echo "No recent files to tar."
    fi
}

# Function to trigger EMS event and generate AutoSupport
trigger_asup() 
    echo "Triggering ASUP for diagnosis"
    ngsh -c "system node autosupport invoke -node local -type all -message IPFW_MAXSTATES_SCRIPT"
}

# Trap termination signals (SIGINT, SIGTERM) to perform cleanup
trap cleanup SIGINT SIGTERM

# Start IPFW monitoring in the background
echo "IPFW Monitoring starting.."
while true; do
    generate_ipfw_output
    sleep 120  # Sleep for 2 minutes
done &

# Start EMS monitoring
echo "EMS Monitoring starting.."
tail -F "$ems_log" | while read -r line
do
    if [[ $line == *$emsMatch* ]]; then
        echo "ipfw.ReachedMaxStates event detected, starting cleanup"
        cleanup
        trigger_asup
        echo "EMS Monitoring stopped.."
        exit 0
    fi
done