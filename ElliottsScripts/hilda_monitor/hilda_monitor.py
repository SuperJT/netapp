#!/usr/bin/env python

import re
import sys
import subprocess
import time

hildaPorts = ['0a',
              '0b']
clusterIP = '10.114.2.30'
nodeName = ['eelliott-cluster-01',
            'eelliott-cluster-02']
proto = 'ssh'
adminUser = 'admin'
#Initialize buffer dict for scope
bufferCounts = {}



def clusterCommand(protocol, ontapAdmin, mgmtIP, command):

    with open('ifstat.out', 'w') as logfile:
        process = subprocess.Popen([protocol, ontapAdmin + "@" + mgmtIP, command], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        for line in process.stdout:
            sys.stdout.write(line)
            logfile.write(line)
    process.wait()
    return 0

while True:
    for node in nodeName:
        for port in hildaPorts:
            clusterCommand(proto, adminUser, clusterIP, 'set d -c off; run -node ' + node + ' -command ifstat e' + port)
            bufferCounts.update()
    time.sleep(60)
