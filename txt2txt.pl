#!/usr/bin/perl -w
use strict;
my ($filename,$total)=('/home/jgilmore/ed2k/incoming/harry potter 5.txt',0);
my (%sizes);
sub countlines()
{
	my($t,$key,$size);
	open(COUNT,$filename) || die ("Can't open callings:$!");
	while(<COUNT>)
	{
		$size=length;
		if( defined $sizes{$size}){
		$t=$sizes{$size}+1;
		}
		else{
		$t=0;
		}
		$sizes{$size}=$t;
		$total+=1;
	}
	foreach $key (sort keys %sizes) {
		print "" . ($size-$sizes{$key}) . "		" ;
		$size=$sizes{$key};
		print $sizes{$key} . "		strings of length " .  $key . "\n";
	}
	print $total . " lines total\n";
	close(COUNT);
}
sub divyfile()
{
	my ($cutoff,$t,$size)=(73);
	open(IN,$filename) || die ("Can't open text:$!");
	open(OUT,">".$filename.".txt") || die ("Can't open text:$!");
	while(<IN>)
	{
		$size=length;
		chomp;
		$t=" ";
		while($t eq " ")
			{$t=chop;}
		next if ord($t)==12;
		print OUT $_,$t," ";
		print OUT "\n\n" if( $size < $cutoff );
		#print OUT $sizes{$size} . "=" . $size;
		#last if $t++>60;
	}
}
countlines();
divyfile();
