'''
Author: Elliott Ecton <elliott.ecton@netapp.com>
Version: 0.1
Python required: 3.5
Future Features: Python2.x instead of 3; parse hostnames correctly
'''

#Initialize variables for scope
values={}
ip_addr= '0.0.0.0'
count= 0
startRead = 'Clients Dump'
stopRead = 'Owners Dump'
startline = 0
stopline = 0

#Get important line numbers
with open('/Users/eelliott/Downloads/BoA/lockStatLast.txt', 'r') as f:
    for i, line in enumerate(f):
        if startRead in line:
            startline = i
        if stopRead in line:
            stopline = i

#Add IP and Lease count to dictionary
with open('/Users/eelliott/Downloads/BoA/lockStatLast.txt', 'r') as f:
    for i,line in enumerate(f):
        if i > startline and i < stopline:
            if "Id String" in line:
                ip_addr = (line.split()[2])
            if "Lease Count" in line:
                count = (line.split()[7])
            else:
                continue
            values[ip_addr] = count

#Write data to file as csv
with open('ClientLeaseCount.csv','a') as theFile:
    for key,value in values.items():
        theFile.write(key + ',' + value + '\n')