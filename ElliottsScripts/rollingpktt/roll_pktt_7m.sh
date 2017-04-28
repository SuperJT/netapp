#!/usr/local/bin/bash

user="root"
hostname="gwl-nas4"
port="all"
seconds=60
snaplen=500
buffer="2m"
path="/nas/pktt" # local mount path
nasvolume="/vol/pktt_trace" # NetApp Volume to write traces to

### DO NOT CHANGE THESE ###
removei=1 
iteration=1
###########################


trap ctrl_c INT

# Upon break, stop packet traces and move last iterations to a folder call 'lastCapture'
function ctrl_c() {
    echo "Stopping Traces"
    ssh $user@$hostname "pktt stop all" > /dev/null
    nodei=1
    while [ $nodei -le $nodes ]; do
        mkdir -p $path/lastCapture
        mv $path/*.trc $path/lastCapture/
        ((nodei++))
    done;
    exit
}

# Start rolling traces
while true; do
    ssh $user@$hostname "pktt start $port -d $nasvolume -s 5g -m $snaplen -b $buffer" > /dev/null
    sleep $seconds
    ssh $user@$hostname "pktt stop all" > /dev/null
    mkdir -p $path/capture$iteration
    mv $path/*.trc $path/capture$iteration/
    capacity=`df $path | grep -v 'Filesystem' | awk '{print $5}' | tr -d %`
	if [ $capacity -ge 80 ]; then
            rm -rf $path/capture$removei/
            echo "Removed capture$removei/"
            ((removei++))
	fi
    echo "Finished Iteration $iteration"
    ((iteration++))
done
