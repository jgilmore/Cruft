#!/usr/bin/perl -w
use strict;
my ($t,$who,$what);
print @_;
($t,undef)=@_;

while(<>){
	next if not /var isbn = "/;
	chomp;chop;
	s/.*([0-9X]{10}?).*/$1/i;
	print $_;
	exit(0);
}
exit(1);
