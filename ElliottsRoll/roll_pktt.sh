#!/usr/bin/bash

user="admin"
hostname="10.113.45.238"
nodename="*"
port="all"
seconds=60
iteration=1
snaplen=500
buffer="2m"
nodes=2
path="/home/eelliott/"
removei=1

trap ctrl_c INT

# Upon break, stop packet traces and move last iterations to a folder call 'lastCapture'
function ctrl_c() {
    echo "Stopping Traces"
    ssh $user@$hostname "system node run -node $nodename pktt stop all" > /dev/null
    nodei=1
    while [ $nodei -le $nodes ]; do
        mkdir -p $path/node$nodei/lastCapture
        mv $path/node$nodei/*.trc $path/node$nodei/lastCapture/
        ((nodei++))
    done;
    exit
}

# Start doing the needful
while true; do
    ssh $user@$hostname "system node run -node $nodename pktt start $port -d /vol/pktt -s 5g -m $snaplen -b $buffer" > /dev/null
    sleep $seconds
    ssh $user@$hostname "system node run -node $nodename pktt stop all" > /dev/null
    nodei=1
    while [ $nodei -le $nodes ]; do
        mkdir -p $path/node$nodei/capture$iteration
        mv $path/node$nodei/*.trc $path/node$nodei/capture$iteration/
        capacity=`df $path/node$nodei | grep -v 'Filesystem' | awk '{print $5}' | tr -d %`
        if [ $capacity -ge 20 ]; then
            rm -rf $path/node$nodei/capture$removei/
            echo "Removed Node$nodei/capture$removei/"
            ((removei++))
        fi
        ((nodei++))
    done;
    echo "Finished Iteration $iteration"
    ((iteration++))
done
