#!/usr/bin/perl -w

my ($last,$First,$note,$in,$wife,@children,$address,$csz,$phone,$callings,%callings);

sub readjunkpage()
{
	my $good=0;
	while(<LIST>){ $good=1;chop;chop;last if( /^==*$/);}
	while(<LIST>){ $good=1;chop;chop;last if( /^==*$/);}
	exit if( !$good);
}
sub addit()
{
	my ($city,$state,$zip)=("","","");
	print "addit:";
	foreach $_ ($last,$First,$note,$in,$wife,@children,$address,$csz,$phone,$callings)
	{
		$_="",next if !defined $_;
		while(/^ /){ s/^ //;}
		while(/ $/){ s/ $//;}
		while(/  /){ s/  / /;}
	}
	$note =~ s/\n/\\n/g;
	$callings = '';

	foreach $_ ($First,$wife,@children)
	{
		$_="",next if !defined $_;
		my $key;
		$key = (uc $last). ',' . (uc $_);
		$callings .= '\n' . $key . ' ' . $callings{$key} if( exists $callings{$key});
	}
	$First .= ' & ' . $wife if( $wife ne "");
	$First .= ':' . join(' ',@children) if( @children);
	($city,$state,$zip)=split(/,? /,$csz) if ($csz ne "");
	#Cedaredge, CO 81413

	print OUT '"' . $last . '","' . $First . '","","","Home";"' . $phone ;
	print OUT '","","","","","'.$address.'","'.$city.'","'.$state.'","'.$zip.'","","'.$callings.'","","","","' . $note . '","0"';
	print OUT "\n";
	print $last . $callings . "\n";

	($last,$First,$note,$in,$wife,@children,$address,$csz,$phone,$callings)=();
}

open(LIST,"list.txt") || die("Can't open list");
open(OUT,">churchlist.cvs") || die("Can't create churchlist.cvs");

#goal:
# "Category";"last name","First name","Country","Title","Company","Work","Home","Fax","Other","E-mail","Address","City","State","Zip Code","Custom 1","Custom 2","Custom 3","Custom 4","Note","Private-Flag"
#"","Abbey","","","Home";"226-2146","","","","","","","","","","","","","","t\ne\ns\nt\n","0"
#
<LIST>;
readjunkpage();

open(CALL,"calling.txt") || die("Can't open callings");
my($key);
while(<CALL>)
{
	$key=uc substr($_,0,40),$key=~s/ //g if( /^[A-Z]/ );
	$_=substr($_,41,31);
	while(/ $/){ s/ $// };
	$callings{$key} .= $_ . ' ';
	print "read:$key = $_\n";
}
close(CALL) || die "Couldn't close callings.txt";

while(<LIST>)
{
	#rem ($last,$First,$note,$in,$wife,@children,$address,$csz,$phone,$callings);
	
	readjunkpage() if( /\014/); #read page header if ^L detected
	next if( not /^[A-Z]/); #Always read until line starts with a capital letter (new family)
	next if( /\(See/ ); #Skip children with seperate names

	chomp;chop;
	($last,$First,$note) = (substr($_,0,40),substr($_,41,63-42),substr($_,63));

	$_= <LIST>;chomp;chop;$in=$_."                                                                    ";

	while( $in =~ /^ / || $in =~ /^ *$/ )
	{
		if( $in =~ /^ *$/ )
		{
			print("Pagebreak in middle of record...\n");
			readjunkpage();
			$_=<LIST>;chomp;chop;$in=$_."                                                                    ";
			substr($in,0,40) = "                                        ";
		}
		if(substr($in,41,1) ne " ") #wife
		{
			$wife = substr($in,41,63-42)
		}
		else #child, maybe
		{
			@children = (@children,substr($in,42,63-43)) if ( substr($in,42,1) ne " ");
		}

		if( $in =~ /^ [0-9]{3}-[0-9]{4}/ )
		{
			$phone = substr($in,1,9);
		}
		elsif( $in =~ /^ [A-Za-z]*?, CO [0-9]{5}/ )
		{
			$csz = substr($in,1,39);
		}
		elsif( $in =~ /^ *$/)
		{
			#Blank Line...
			print("Blank Line...\n");
		}
		else
		{
			$address = substr($in,0,41);
		}
		$note = $note . '\n' . substr($in,63);

		$_=<LIST>;chomp;chop;$in=$_."                                                                    ";
	}
	addit();
}
