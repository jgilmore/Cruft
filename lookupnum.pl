#!/usr/bin/perl -w
use strict;
my (@headers,$number,$name,$count);
while(<>)
{
	$headers[$#headers+1]=$_;
	if( /in mailbox 9702322022 from /)
	{
		$number=substr($_,28,10);
	}
#Content-Type: audio/x-WAV; name="msg0003.WAV"
#Content-Transfer-Encoding: base64
#Content-Description: Voicemail sound attachment.
#Content-Disposition: attachment; filename="msg0003.WAV"
	elsif( /^Content-Disposition:/)
	{
		if(/filename="msg([0-9]{4}).WAV"/)
		{
			$count=$1
		}
		last;
	}

}
$name=`/home/jgilmore/bin/callerid.sh $number`;
chomp $name;

for my $th ( @headers ){
	if( $th =~ /^Subject:/ )
	{
		print "Subject: new message $count from $name (${number})\n";
	}
	elsif( $th =~/^Content-Type: audio\/x-WAV; name="/ or $th =~ /^Content-Disposition: attachment; filename="/)
	{
		#Mangle filename
		if( $name=='')
		{
			$th =~ s/"msg[0-9]{4}.WAV"/"msg$number.WAV"/;
		}
		else
		{
			$th =~ s/"msg[0-9]{4}.WAV"/"msg$number.WAV"/;
		}
		print $th;
	}
	else
	{
		print $th;
	}
}


print while(<>);

