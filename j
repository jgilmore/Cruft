#!/bin/bash
# Automatically edit a new journal entry, with spell check after.

FILE="$HOME/docs/Journal/`date '+Journal entry %F.txt'`"
echo $0
if [ "${0##*/}" = "j" ]; then
	vim "$FILE"
	if [ -e "$FILE" ]; then	
		ispell "$FILE"
	fi
elif [ "${0##*/}" = "js" ]; then
	vim "$FILE"
	ispell "$FILE"
else
	echo "huh? I'm not called that?"
fi
