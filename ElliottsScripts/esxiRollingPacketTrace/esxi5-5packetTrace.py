#!/usr/bin/env python

"""
This script has been tested in ESXi CLI 5.5.
Version: 1.0
Author: Elliott Ecton
Email: elliott.ecton@netapp.com
"""

import os
import time

NetAppIP = "10.112.77.167"  # This is the NFS LIF IP to filter on
vmknic = ["vmk0"]  # Add more vmknics if needed. Format is ["vmk0","vmk1",etc...]
snaplen = "500"  # May need increased for NFSv4
filePath = "/vmfs/volumes/nfs_datastore/"  # Must include the trailing slash
outFile = "esxi_trace.trc"  # Suggest you don't change
sleepSeconds = 120  # How long each trace should run in seconds before stopping and starting new ones
filesToKeep = 30  # NOTE: The actual number of files kept will this value x 2 x number of vmknics in variable above
counter = 1  # DO NOT CHANGE
removeCounter = 1  # DO NOT CHANGE

while True:
    for port in vmknic:
        txCommand = "pktcap-uw --ip " + NetAppIP + " -s " + snaplen + " -o " + filePath + port + "_TX_" + outFile + str(
            counter) + " --vmk " + port + " --dir 0 &"
        rxCommand = "pktcap-uw --ip " + NetAppIP + " -s " + snaplen + " -o " + filePath + port + "_RX_" + outFile + str(
            counter) + " --vmk " + port + " --dir 1 &"
        os.system(txCommand + " " + rxCommand)
    time.sleep(sleepSeconds)
    os.system("pkill pktcap-uw")
    counter += 1
    if counter > filesToKeep:
        os.system("rm -rf " + filePath + "*.trc" + str(removeCounter))
        removeCounter += 1
