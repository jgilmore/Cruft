#!/bin/bash


#Open a message - giving option to type in who it's from...
killall mplayer
mplayer $1 &
number=${1%%.message*}
number=${number##*/msg}
name=`zenity --entry --title "set CallerID name association" --text "Who called from $number?"`

if [ -n "$name" ] ; then
	/home/jgilmore/bin/callerid.sh "$number" manual "$name">/dev/null
fi
