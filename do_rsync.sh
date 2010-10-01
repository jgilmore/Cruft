#!/bin/bash
# ----------------------------------------------------------------------
# mikes handy rotating-filesystem-snapshot utility
# ----------------------------------------------------------------------
# this needs to be a lot more general, but the basic idea is it makes
# rotating backup-snapshots of /home whenever called
# ----------------------------------------------------------------------

unset PATH	# suggestion from H. Milz: avoid accidental use of $PATH

# ------------- Configuration ------------------------------------------

COPIES="$1"
SOURCE="$2"
DEST="$3"
EXCLUDES="$4"

# ------------- system commands used by this script --------------------
ID=/usr/bin/id
ECHO=/bin/echo

MOUNT=/bin/mount
RM=/bin/rm
MV=/bin/mv
CP=/bin/cp
CAT=/bin/cat
EXPR=/usr/bin/expr
TOUCH=/bin/touch
DATE=/bin/date

RSYNC=/usr/bin/rsync


# ------------- the script itself --------------------------------------
function Usage {
	$CAT <<- END
	Usage: $0 <Copies> <SourceDir> <DestName> <ExcludesFile>

	Makes incremental snapshot-style backups using rsync.
	<sourcedir> is the directory to copy from. It's name does not end up in destname AT ALL
	<destname> is where to put the backups. a ".0" is appened to this to get the backup name,
	and the old ".0" directory is rotated to ".1", up to <copies>. It is then named .tmp
	and deleted before the next backup starts.
	<excludesfile> is required, and contains file patterns to ignore, one per line. See
	the rsync documentation for details.
	
	END
}

function is_absolute {
	if [ -z "$1" ]; then
		echo ERROR: "$2" is not set! "$2" must be set! >/dev/stderr
		Usage
		exit 2
	fi
	if [ ${1:0:1} != "/" ]; then
		echo ERROR: "$2" is \"$1\", which doesn\' start with a \"/\" >/dev/stderr
		Usage
		exit 2
	fi
	if [ ${1:-1:1} = "/" ]; then
		echo ERROR: "$2" is \"$1\", which ends with a \"/\" >/dev/stderr
		Usage
		exit 2
	fi
}
if [ `$EXPR $COPIES - 1 + 1` -ne $COPIES ]; then
	echo ERROR: "<Copies>" must be numeric! >/dev/stderr
	Usage
	exit 2
fi
is_absolute "$SOURCE" "<SourceDir>"
is_absolute "$DEST" "<DestName>"
is_absolute "$EXCLUDES" "<ExcludesFile>"
exit 3

# Make sure we're running as root

##############if (( `$ID -u` != 0 )); then { $ECHO "Sorry, must be root.  Exiting..."; exit; } fi

# Remove the oldest backup. This is kept until time to do the next backup.
# This is so that the weekly/monthly rotation scripts can grab it.
if [ -d "$DEST.tmp" ]; then
	echo Removing outdated snapshot...
	$RM -rf "$DEST.tmp" || echo "Failed to remove outdated snapshot." >/dev/stderr
fi

# Rotating snapshots
# Note: if this fails, we don't care, it'll leave the snapshots is a consistent state:
#  dest.0 won't exist dest.tmp may exist.
/home/jgilmore/bin/rotate_snapshots.sh $COPIES "$DEST" || exit 1


# Make a hard-link-only (except for dirs) copy of the latest snapshot,
# if that exists
#if [ -d "$DEST.1" ] ; then			
#	$CP -al "$DEST.1" "$DEST.0"
#fi

# rsync from the system into the latest snapshot (notice that
# rsync behaves like cp --remove-destination by default, so the destination
# is unlinked first.  If it were not so, this would copy over the other
# snapshot(s) too!
$RSYNC\
	-va --delete --delete-excluded\
	--exclude-from="$EXCLUDES"\
	--link-dest="$DEST.1"\
	"$SOURCE/" "$DEST.0"

RES=$?

if [[ $RES -eq 0 && -d "$DEST.0" ]]; then
	echo Backup finished at `$DATE`
	# update the mtime of hourly.0 to reflect the snapshot time
	$TOUCH "$DEST.0" ;
else
	echo '**********************************' >/dev/stderr
	echo Backup failure at `$DATE` >/dev/stderr
	echo '**********************************' >/dev/stderr
	# failure! email root! panic! Run in circles, scream and shout!

	#Remove failed partial copy (if it exists)
	if [ -d "$DEST.0" ]; then
		echo "Removing failed partial backup..."
		$RM -rf "$DEST.0" || echo "Failed to remove partial destination directory: $? $!" >/dev/stderr
	fi
fi



