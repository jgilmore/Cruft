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
	vim "`find $HOME/docs/Journal | sort -r | head -n $line | tail -n 1`"
fi

exit

***Comments***

<jgilmore> How can I open a non-existant file with pre-set contents? Specifically, I have a command (j, details at https://github.com/jgilmore/Cruft/blob/746b1c99940355af752fc7533968642a9aa6d70b/j ) that opens a new journal entry. I would like new entries to have a reminder of the syntax I should log various things in. (I'm trying to track my progress, and want to remember to log it there)
<Raimondi> jgilmore: See  :h template
<jgilmore> ah. Thank you. I think that will work with an appropriately path-specific autocmd invocation. Glad I asked.
<Raimondi> jgilmore: You could also pass a :read command to vim from an argument. See  :h -c
<jgilmore> Raimondi: Already finished it. Tested even. Now I just have to see if it really meets my needs. Mostly that should be modifying "~/.vim/skeleton.journalentry.txt" at this point though. And it only triggers for text files in ~/docs/Journal so shouldn't cause unexpected side-effects.
<Raimondi> If it ain't broken... :)
<jgilmore> Thank you for the extra suggestion. It might be nice to have a more centrialized control system. It would be more elegant to have everything (including the skeleton) inside the "j" script.
