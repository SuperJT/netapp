

import subprocess, os, time, sys, re

username="admin"
clusterip="10.114.2.30"
proto="ssh"
node="eelliott-cluster-01"
ownerAllocThresh=117965
ownerMax=131072

# Function to run cluster level commands and pipe output to a file called 'logfile'
def clusterCommand(protocol, ontapAdmin, mgmtIP, command):
    with open('logfile', 'w') as logfile:
        process = subprocess.Popen([protocol, ontapAdmin + "@" + mgmtIP, command], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        for line in process.stdout:
            sys.stdout.write(line)
            logfile.write(line)
    process.wait()
    return 0


clusterCommand(proto,username,clusterip,"set d -c off ; statistics show -object nfsv4_diag -counter storePool_OwnerAlloc -raw -node " + node)
with open('logfile', 'r') as f:
    for line in f:
        line = re.findall('storePool_OwnerAlloc', line)
        if line:
            print(line.split())
