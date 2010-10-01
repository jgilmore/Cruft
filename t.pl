#!/usr/bin/perl


while(<>)
{ 
	chomp;
	foreach(split //)
	{ 
		defined $t{$_} or $t{$_}=0;
		$t{$_} += 1;
	} 
} 
foreach(keys %t )
{ 
	printf "%13d: %s\n",$t{$_}, $_;
}
