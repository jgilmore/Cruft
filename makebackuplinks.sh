#!/bin/bash
BACKUPDIR=/var/backup/herb/localhost/home
cd /home

#First, remove all old symlinks
for USER in *; do
    USERDIR=/home/$USER/backup
    #remove old symlinks, don't print anything about failures
    rm $USERDIR/* 2>/dev/null
done

#parse STATUS file.
cat /var/backup/herb/localhost/home/STATUS | sort |uniq --check-chars 5 | {
    IFS=','
    while read NAME DATE JUNK; do
        for USER in *; do
            USERDIR=/home/$USER/backup
            # Due to the "uniq" invocation and the fact we removed everything first, these should always work.
            ln -s $BACKUPDIR/$NAME/$USER $USERDIR/$NAME 
            ln -s $BACKUPDIR/$NAME/$USER $USERDIR/$DATE
        done
    done
}
