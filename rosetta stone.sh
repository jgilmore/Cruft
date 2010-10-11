#!/bin/bash
#created 10/10/2010 jgilmore.
#Just some simple things that seem to get resetta stone 3 to work under wine
#Also, if this script isn't started from a console rosetta stone is slow as crap.

#Starting from the correct directory prevents the infamous error 2123
cd ~/.wine/drive_c/Program\ Files/Rosetta\ Stone/Rosetta\ Stone\ Version\ 3
wine ./RosettaStoneVersion3.exe &

#For some insane reason, rosetta stone doesn't unmute the microphone, but does increase the volume.
#On my particular hardware, the Mic *must* be unmuted to work, but doesn't need to be turned up,
#and if it *is* turned up, I can hear my own voice echo *loudly* on the headset.
#so reset those paremeters every five seconds until rosetta stone dies.

while true; do
	sleep 5
	amixer set Mic 0 unmute
	if [ "$CHILD_DIED" == "1" ];then
		echo Definately done!
		exit
	fi
	if ps | grep '[R]osetta' ; then
		CHILD_DIED=0
	else
		CHILD_DIED=1
	fi

done

