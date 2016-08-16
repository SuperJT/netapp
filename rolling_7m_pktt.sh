#!/bin/bash
#
filer=<filername_or_IP>         # User either IP address or host name of filer
interface=<interface_name>      # Which interface to use for the captures
targethost=<ip_address_of_host> # IP address of a target host experiencing the issue
saved=<num_to_save>             # The number of both packet traces to save
hourstocapture=<num_of_hours>	# How many hours the script should run
capsize=<max capture_size>		# Maximum size of a capture file
savedir=<dire_to_save_files>	# Subdir of /etc/crash
interval=<num_mins>				# number of minutes to capture
bufsize=<buffer_size>			# pktt buffer size
packetsize=<frame_cap_size>		# size of the frame to capture
#
# NOTE: The "traces" directory is off the root volume of the filer NFS mounted on this client so that
#       packet trace and lock status files can be pruned periodically.

for g in {1..($hourstocapture*3600)}
        do 
		hash=$(date +%F_%H%M%S)
		#test for mounted filer
		if [-z /mnt/$filer/vol0/etc/$g]
		
		
		/usr/bin/ssh $filer "pktt start $interface -d /etc/crash/traces -m $packetsize -b $bufsize -i $targethost"
        sleep ($interval*60)
        /usr/bin/ssh $filer "pktt stop $interface"
		
		
		
		/usr/bin/mv /mnt/$filer/vol0/etc/crash/*.trc /mnt/$filer/vol0/etc/$g/
        d=$((g-$saved))

        # Prune older trace and nlm stat files
        if [ $d -gt 0 ]
        then
                /usr/bin/rm /mnt/$filer/vol0/etc/traces/$interface.trace.$d /mnt/$filer/vol0/etc/traces/lockcollect.$d
        fi
done
