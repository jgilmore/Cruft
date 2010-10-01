#!/usr/bin/perl -w
use strict;
my ($t,$who,$what);
print @_;
($t,undef)=@_;

while(<>){
	next if not /^<title>/;
	chomp;chop;
	s'</?title>''ig;
	s/ &amp; /, /;
	($what,$who)=split / by /;
	($who,undef)=split(" - ",$who);
	print "$who-$what\n";
	exit(0);
}
exit(1);
