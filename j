#!/bin/bash
if [ "$1" == "" ]; then	
	# Automatically edit a new journal entry, with spell check after.
	FILE="$HOME/docs/Journal/`date '+Journal entry %F.txt'`"
	if [ "${0##*/}" = "j" ]; then
		vim "$FILE"
		if [ -e "$FILE" ]; then	
			ispell -x "$FILE"
		fi
	elif [ "${0##*/}" = "js" ]; then
		vim "$FILE"
		ispell -x "$FILE"
	else
		echo "huh? I'm not called that?"
	fi
else
	# View yesterday's journal entry.
	line=$(($1 + 1))
	less "`find $HOME/docs/Journal | sort -r | head -n $line | tail -n 1`"
fi
