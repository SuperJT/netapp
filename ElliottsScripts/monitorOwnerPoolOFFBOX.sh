#!/usr/bin/env bash

hostname="eelliott-cluster-01"
username="admin"
clustermgmtip="10.114.2.30"
caseNumber="2006390542"
to="eelliott@netapp.com"
subject="WARNING! OWNER ALLOCATIONS HAVE CROSSED THE 90% THRESHOLD!!!"
message="message.txt"
ownerAllocThresh=117964
sleepseconds=60

while TRUE; do
ssh $username@$clustermgmtip "set d -c off; statistics show -object nfsv4_diag -counter storePool_OwnerAlloc -node $hostname -raw" > tmp.counter
ownerAlloc=$(grep -i 'storePool_OwnerAlloc' tmp.counter | awk '{print $2}')
    if [[ $ownerAlloc < 117964 ]]; then
        echo "$(date),$ownerAlloc" >> ownerAllocbyTime.csv
        sleep $sleepseconds
    else
        echo "$(date),$ownerAlloc" >> ownerAllocbyTime.csv
        echo "Node $hostname has breached the 90% threshold for allocatable Owner State IDs at $(date). Please core $hostname using the following steps:" >> $message
        echo "1. Login to the SP/RLM/BMC as admin" >> $message
        echo "2. Run command 'system core'" >> $message
        echo "3. Confirm the shutdown" >> $message
        echo "4. Run command 'system console'. This will allow you to watch the progress of the core dump via the dots" >> $message
        echo "5. Please call Technical Support at 888-4-NetApp and enter case #$caseNumber" >> $message
        ### Please edit the following line to support your mail system
        mail -s "subject" "$to" < $message
        sleep $sleepseconds
    fi
done