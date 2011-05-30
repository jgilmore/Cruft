#!/bin/bash
#
# simpletimer.sh
#
# Simple timer script.
#
SLEEPARG=`zenity --entry --title="Simple Timer" \
	--text="Enter time. (1.5m-noodles)(0.5h-time to leave for work)"`
sleep ${SLEEPARG%-*}


playonce forget remember don.t

zenity --info --title="Simple Timer" --text="The ${SLEEPARG#*-} Timer is up." &


beep
beep
beep
