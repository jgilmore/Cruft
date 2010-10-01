#!/usr/bin/perl
use strict;
# $delay is the number of screen switches to wait
# before suspending to disk.
# How long exactly that is depends on how often
# xscreensaver is configured to switch modes.
my ($delay) = (5);
															
my ($blanked,$count,$stopped) = (0,0,0);
open (IN, "xscreensaver-command -watch |") or die "Can't fork xscreensaver-command:$!\n";
while (<IN>) {
	if (m/^(BLANK|LOCK)/) {
		
	} elsif (m/^UNBLANK/) {
		$count = 0;
		$blanked = 0;
		$stopped = 0;
	} elsif ( /^RUN/ ) {
		$count += 1;
		if($count > $delay && not $stopped ) {
			# We set stopped here, to prevent hibernating again without first clearing the screensaver.
			# This means that if you turn it back on, it'll stay on. Unless you deactivate the screensaver.
			$stopped = 1;
			#Hibernate!
			system('/usr/bin/curl http://127.0.0.1/cgi-bin/shutdown.pl');
		}
	}
}
close IN;
