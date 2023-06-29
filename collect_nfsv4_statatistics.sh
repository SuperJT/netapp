#!/bin/bash

#Set the IP address of the node management server
NODE_MANAGEMENT="NODE-MGMT-IP"  # NODE_MANAGEMENT="10.2.1.3"

#Set the username to user during authentication (Ideal to use pubkey auth)
USERNAME="admin"

#Create a directory to store the statistics
mkdir -p statistics/$NODE_MANAGEMENT


#Collect the statistics for NFSv4 and NFSv4_1
for version in nfsv4 nfsv4_1
do
    for TYPE in "" "_diag" "_error"
    do
        ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; statistics show -object $version$TYPE -raw" >> statistics/$NODE_MANAGEMENT/nfs.txt
    done
done

#Collect the statistics for spinnp
for TYPE in spinnp_error spinhi spinnp
do
ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; statistics show -object $TYPE -raw" >> statistics/$NODE_MANAGEMENT/spin.txt
done

#Collect the statistics for lmgr_ng
ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; statistics show -object lmgr_ng -counter files|hosts|owners|locks|*max -raw" >> statistics/$NODE_MANAGEMENT/locks.txt

#Collect the statistics for vserver locks nfsv4
ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; vserver locks nfsv4 show -inst" >> statistics/$NODE_MANAGEMENT/locks.txt
