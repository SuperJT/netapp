#!/usr/bin/env python2.7

from sys import argv

# Initialize the dictionary
perms={}

i=0

value= argv[1]
b = bin(int(value,16))
b = b[2:].zfill(32)

with open("PermissionList", 'r') as f:
    for line in f:
        perms[line.strip()]=b[i]
        i+=1

print "*** Permissions Granted ***"

for key, value in perms.iteritems():
    if perms[key]=='1':
        print key


print "\n*** Permissions Denied ***"
for key, value in perms.iteritems():
    if perms[key]=='0':
        print key


