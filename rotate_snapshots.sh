#!/bin/bash 
CAT=/bin/cat
MV=/bin/mv

# Require two parameters, the first of which must be a number.
if [[ -n "$2" || -n "$1" || $(($1 + 1 - 1)) -ne $1 ]]; then
	$CAT <<- this
		Useage: $0 count directory

		Rotates directories, moving directory.0 to directory.1,
		directory.1 to directory.2  ... directory.(n-1) to directory.n

		Moves directory.n to directory.tmp

		directory.tmp MUST NOT exist!
		directory.0 MUST exist!

	this
	exit 1
fi

curr=$1
dir=$2


if [ ! -d "$dir.0" ]; then
	echo directory \"$dir.0\" does not exist. Nothing to to.
	# exit WITHOUT an error. Nothing to do, but that's OK.
	exit
fi

if [ -d "$dir.tmp" ]; then
	echo Directory \"$dir.tmp\" exists! Cannot safely rotate!
	# exit WITH an error.
	# The .tmp file should have been deleted before this.
	exit 2
fi

if [ -d "$dir.$curr" ]; then
	$MV "$dir.$curr" "$dir.tmp" || exit 2
#	echo Not moved: \"$dir.$curr\" to \"$dir.tmp\": because \"$dir.$curr\" doesn\'t exist.
fi


while [ $curr -ne 0 ]; do
	next=$curr
	curr=`expr $curr - 1`

	if [ -d "$dir.$curr" ]; then
		$MV "$dir.$curr" "$dir.$next" || exit 2
#		echo Not moved: \"$dir.$curr\" to \"$dir.$next\": because \"$dir.$curr\" doesn\'t exist.
	fi
done
