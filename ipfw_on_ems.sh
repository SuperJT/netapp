#!/bin/bash
# ------------------------------------------------------------------
# [Author: Jason Townsend] 
#		   Monitor ems.log for ipfw.ReachedMaxStates lines.  
#          Once this finds the event, trigger cleanup to tar files.
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
}

# Function to count and sort IP pairs from recent files and append the summary to each file
count_and_sort_ip_pairs() {
    # Find files modified within the last 10 minutes
    recent_files=$(find "$output_dir" -type f -name "ipfw_dyn_list_*.txt" -mmin -10)

    # Check if there are any recent files
    if [ -z "$recent_files" ]; then
        echo "No recent files to process."
        return
    fi

    # Process each recent file
    for file in $recent_files; do
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
        ' "$file" | sort -nr >> "$file"
    done
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
    exit 0
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
        count_and_sort_ip_pairs
        cleanup
        echo "EMS Monitoring stopped.."
        exit 0
    fi
done