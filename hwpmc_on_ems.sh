#!/bin/bash
# ------------------------------------------------------------------
# [Author: Jason Townsend] 
#		   Monitor ems.log for bgp.vserver up and vserver down lines.  
#          Once this finds a down event trigger collect profile
#          Stop upon finding a bgp.vserver 
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
# curl -k0 https://raw.githubusercontent.com/SuperJT/netapp/master/hwpmc_on_ems.sh > hwpmc_on_ems.sh
# aff700s-2n-rtp-2::*> event generate -node local -message-name vifmgr.bgp.vserverDown jtown Default
# aff700s-2n-rtp-2::*> event generate -node local -message-name vifmgr.bgp.vserverUp jtown Default
hwpmc_pid=0

# Download the script if it does not exist
if [[ ! -f collectProfile-1.3-beta.sh ]]; then
    echo "collectProfile-1.3-beta.sh does not exist. Downloading the script..."
    curl -kO https://raw.githubusercontent.com/SuperJT/netapp/master/collectProfile-1.3-beta.sh
    if [[ $? -ne 0 ]]; then
        echo "Failed to download collectProfile-1.3-beta.sh. Please check your network connection and try again."
        exit 1
    fi
fi
echo "EMS Monitoring starting.."
tail -f /mroot/etc/log/ems | while read -r line
do
    if [[ $line == *"vifmgr_bgp_vserverDown_1"* ]]; then
        echo "vserverDown event detected, starting hwpmc script"
        ngsh -c "set d -c off;event generate -node local -message-name tape.diagMsg hwpmc starting"
        if [[ $hwpmc_pid -eq 0 ]]; then  # Only start the script if it's not already running
            bash collectProfile-1.3-beta.sh -d network &  # Start the hwpmc script in the background
            break  # Exit the loop
        fi
    fi
done
