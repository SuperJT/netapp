#!/usr/bin/env bash


ownerAllocThresh=128450
sleepseconds=60
sudo touch /mroot/etc/crash/ownerAlloc.log

while true; do
ownerAlloc=$(ngsh -c "set d -c off; statistics show -object nfsv4_diag -counter storePool_OwnerAlloc -node `hostname` -raw" | grep -i storePool_OwnerAlloc | awk '{print $2}')
if [ "$ownerAllocThresh" -le "$ownerAlloc" ]; then
	sudo echo "`date`,$ownerAlloc" >> /mroot/etc/crash/ownerAlloc.log
	sleep $sleepseconds

else
	sudo touch /mroot/etc/crash/ownerAllocThreshBreached.log
	echo "`date`,$ownerAlloc. Please consider coring node `hostname` ASAP" >> /mroot/etc/crash/ownerAllocThreshBreached.log
fi

