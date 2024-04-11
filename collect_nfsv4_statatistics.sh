#!/bin/bash

# Prompt for node management IP and username
read -p "Enter the IP address of the node management server: " NODE_MANAGEMENT
read -p "Enter the username: " USERNAME

TIMESTAMP=$(date +%m-%d-%y-%H:%M:%S)
STATS_DIR="statistics/$TIMESTAMP/$NODE_MANAGEMENT"

# Create a directory to store the statistics
mkdir -p "$STATS_DIR"

# Function to collect statistics
collect_stats() {
    local type=$1
    local file=$2
    local counters=$3

    printf ".. collecting %s stats\n" "$type"
    ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; statistics show -object $type -counter $counters -raw" >> "$STATS_DIR/$file.txt" || {
        printf "Failed to collect %s stats\n" "$type"
        exit 1
    }
}

printf 'Init Collection\n'
printf '%s@%s on %s\n' "$USERNAME" "$NODE_MANAGEMENT" "$TIMESTAMP"

# Collect the statistics for NFSv4 and NFSv4_1
for version in nfsv4 nfsv4_1; do
    for type in "" "_diag" "_error"; do
        collect_stats "$version$type" "nfs"
    done
done

# Collect the statistics for spinnp
for type in spinnp_error spinhi spinnp; do
    collect_stats "$type" "spin"
done

# Collect the statistics for lmgr_ng
collect_stats "lmgr_ng" "locks" "files|hosts|owners|locks|*max"

# Collect the statistics for vserver locks nfsv4
printf ".. collecting nfsv4 locks stats.  Printing sorted list of clients\n"
ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; systemshell -node * -command "ngsh -c "set d -c off; vserver locks nfsv4 show -inst""" | tee "$STATS_DIR/locks.txt" | grep -i "client name" | sort | uniq -c | sort -n