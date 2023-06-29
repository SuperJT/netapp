#!/bin/bash

#Set the IP address of the node management server
NODE_MANAGEMENT="NODE_MGMT_IP"  # NODE_MANAGEMENT="10.2.1.3"

#Set the username to user during authentication (Ideal to use pubkey auth)
USERNAME="admin"

#Create a directory to store the statistics
mkdir -p statistics


#Collect the statistics for NFSv4
for TYPE in v4 v4_1
do
ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; statistics show -object nfs$TYPE -raw" >> statistics/nfs.txt
ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; statistics show -object nfs{$TYPE}_diag -raw" >> statistics/nfs.txt
ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; statistics show -object nfs{$TYPE}_error -raw" >> statistics/nfs.txt
done

#Collect the statistics for spinnp
for TYPE in spinnp_error spinhi spinnp
do
ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; statistics show -object $TYPE -raw" >> statistics/spin.txt
done

#Collect the statistics for lmgr_ng
ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; statistics show -object lmgr_ng -counter files|hosts|owners|locks|*max -raw" >> statistics/locks.txt

#Collect the statistics for vserver locks nfsv4
ssh $USERNAME@$NODE_MANAGEMENT "set d -c off; rows 0; date; vserver locks nfsv4 show -inst" >> statistics/locks.txt