#!/bin/bash
MYNAME="DontCatchFire"
export PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin:/usr/local/bin
while true; do
    temp=`sensors | grep 'CPU Temp' | cut -f 2 -d '+' | cut -f 1 -d '.'`
    cool=$(( $temp < 75 ))
    panic=$(( $temp > 80 ))
    if [ $cool == 1 ];then
        echo ondemand | tee /sys/devices/system/cpu/cpu?/cpufreq/scaling_governor > /dev/null
    else
        echo powersave | tee /sys/devices/system/cpu/cpu?/cpufreq/scaling_governor > /dev/null
        logger -i -p daemon.info -t $MYNAME "temp=$temp set to powersave to bring the temp down."
    fi
    if [ $panic == 1 ];then
        logger -i -p daemon.crit -t $MYNAME "temp=$temp ***********************************"
        logger -i -p daemon.crit -t $MYNAME "temp=$temp Starting emergency system shutdown."
        logger -i -p daemon.crit -t $MYNAME "temp=$temp ***********************************"
        shutdown -h now
    fi
    #echo $temp $cool $panic
    sleep 30
done
