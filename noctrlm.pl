#!/usr/bin/perl -w

my @everything;
my $lines=0;

open(IN,$ARGV[0]) or die "No File Specified";
while(<IN>)
{
	s/\r//;
	$everything[$lines++] = $_;
}
close(IN);
open(OUT,">" . $ARGV[0] ) or die "Can't write to that file!";

for(@everything)
{
	print OUT $_;
}
close(OUT);
