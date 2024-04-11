#!/usr/bin/env bash
# for 7-mode hostname lookup
# takes in a list of hostnames (source/hosts)
# runs getxxbyyy against each of them
# run with: bash lookup_name.sh > lookupoutput.txt
# Collect both lookupoutput.txt and output.txt for upload

fileread=$(<source/hosts)
for i in ${fileread[@]}; do
    OUTPUT=($(ngsh -n "priv set diag ; getXXbyYY gethostbyname_r $i"))
    echo ${OUTPUT[*]} >> output.txt
done