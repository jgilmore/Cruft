#!/usr/bin/perl -w
# Copyright 2000 John Gilmore
# Converts HTML code to Plain Text.
# Written as part of converting books from http://www.baen.com
# into plain text prepatory to compression for reading
# on my palmPilot.

my $skip = 0;
my $linenum=0;
my $style = 0;
while(<>)
{
	$linenum++;
	#Remove hyperlinks and hyperlink texts
	s/\<a.*?\>.*?\<\/a\>//g;


	# Remove the ^M^L from the end of each line.
	s/[\n\r]//g;

	#Deal with <p> and <br>
	#hack: also convert <li> and <td> to \n
	s/\<br\>/\n/gi;
	s/\<p.*?\>/\n\n/gi;
	s/\<li\>/\n/gi;
	s/\<td\>/\n/gi;

	while( /[ \t]{2}/ )
	{
		s/[ \t]{2}/ /g;
	}
	if( /\<style[^\>]*\>/i )
	{ 
		if( /\<\/style[^\>]*\>/i ) { } else {
			s/\<\/style[^\>]*\>.*$//gi;
			$style = TRUE;
		}
	}
	else
	{
		if( $style )
		{
			if( /\<\/style[^\>]*\>/i )
			{
				s/^.*\<\/style[^\>]*\>//gi;
				$style = 0;
			}
			else
			{
				#print "skipping style line\n";
				next;
			}
		}
	}

	#Remove html tags
	s/\<.*?\>//g;

	#Remove multi-line html tags, such as sections of javascript.
	if( /\</ )
	{
		$skip=1;
		next;
	}
	if( $skip == 1 )
	{
		if( /\>/ ){
			$skip=0;
			s/^[^>]*\>//;
		}
		else
		{
			#print "skipping multi-line tag...\n";
			next;
		}
	}

	#Substitute html characters
	if( /&.[a-zA-Z0-9]{1,6}?;/ )
		{
		#Misc. special characters.
		s/\&lt;/</gi;
		s/\&gt;/>/gi;
		s/\&mdash;/--/gi;
		s/\&amp;/&/gi;
		s/\&copy;/(c)/gi;
		s/\&nbsp;/ /gi;
		s/\&npsp;/  /gi; #Misspelling?
		s/\&oslash;/(theta)/gi;
		s/\&ccedil;/(c)/gi;
		s/\&quot;/"/gi;
		s/\&rdquo;/"/gi;
		s/\&ldquo;/"/gi;
		s/\&rsquo;/'/gi;
		s/\&hellip;/.../gi;
		s/\&reg;/(r)/gi;

		s/\&\#151;/--/gi;
		s/\&\#?8211;/-/g;
		s/\&\#8226;/*/g;

		#Do Generic character # interpretation.
		#FIXME: What does the '8' in front mean?
		#Evidentally, it doesn't mean a octal char!
		while( /\&#[0-9]{1,4}?;/ )
		{
			if( /(.*)(\&#[0-9]{1,4};)(.*)/ )
			{
				my ($first,$second,$third)=($1,$2,$3);
				$second =~ s/\&#//;
				$second =~ s/;//;
				print "[" . $second.  "]";
				#if( $second =~ /^8/ )
				#{
				#	print "[" . $second.  "]";
				#	$second =~ s/^8//;
				#	#print "[" . $second.  "]";
				#}
				#else
				##{
				#	$second = sprintf( "%o", $second);
				#	#print "[" . $second.  "]";
				#}
				#eval( " \$second = \"\\$second\" ");
				#print "[" . $second.  "]";
				$_ = $first . chr($second) . $third;
			}
		}

		s/\&ntilde;/n/g; #		s/\&ntilde;/ñ/g; 
		s/\&Ntilde;/N/g; #		s/\&Ntilde;/Ñ/g;

		#Circumflex, the little hat looking thing.
		s/\&Acirc;/A/g; #		s/\&Acirc;/Â/g;
		s/\&Ocirc;/O/g; #		s/\&Ocirc;/Ô/g;
		s/\&Ecirc;/E/g; #		s/\&Ecirc;/Ê/g;
		s/\&Ucirc;/U/g; #		s/\&Ucirc;/Û/g;
		s/\&Icirc;/I/g; #		s/\&Icirc;/Î/g;
		s/\&acirc;/A/g; #		s/\&acirc;/â/g;
		s/\&ocirc;/o/g; #		s/\&ocirc;/ô/g;
		s/\&ecirc;/e/g; #		s/\&ecirc;/ê/g;
		s/\&ucirc;/u/g; #		s/\&ucirc;/û/g;
		s/\&icirc;/i/g; #		s/\&icirc;/î/g;
		#		
		#Umlate, the two little dots.
		s/\&Auml;/A/g; #		s/\&Auml;/Ä/g;
		s/\&Ouml;/O/g; #		s/\&Ouml;/Ö/g;
		s/\&Euml;/E/g; #		s/\&Euml;/Ë/g;
		s/\&Uuml;/U/g; #		s/\&Uuml;/Ü/g;
		s/\&Iuml;/I/g; #		s/\&Iuml;/Ï/g;
		s/\&auml;/a/g; #		s/\&auml;/ä/g;
		s/\&ouml;/o/g; #		s/\&ouml;/ö/g;
		s/\&euml;/e/g; #		s/\&euml;/ë/g;
		s/\&uuml;/u/g; #		s/\&uuml;/ü/g;
		s/\&iuml;/i/g; #		s/\&iuml;/ï/g;

		#Acute, the /
		s/\&Aacute;/A/g; #		s/\&Aacute;/Á/g;
		s/\&Oacute;/O/g; #		s/\&Oacute;/Ó/g;
		s/\&Eacute;/E/g; #		s/\&Eacute;/É/g;
		s/\&Uacute;/U/g; #		s/\&Uacute;/Ú/g;
		s/\&Iacute;/I/g; #		s/\&Iacute;/Í/g;
		s/\&aacute;/a/g; #		s/\&aacute;/á/g;
		s/\&oacute;/o/g; #		s/\&oacute;/ó/g;
		s/\&eacute;/e/g; #		s/\&eacute;/é/g;
		s/\&uacute;/u/g; #		s/\&uacute;/ú/g;
		s/\&iacute;/i/g; #		s/\&iacute;/í/g;
		
		#Grate Accent, the \
		s/\&Agrave;/A/g; #		s/\&Agrave;/À/g;
		s/\&Ograve;/O/g; #		s/\&Ograve;/Ò/g;
		s/\&Egrave;/E/g; #		s/\&Egrave;/È/g;
		s/\&Ugrave;/U/g; #		s/\&Ugrave;/Ù/g;
		s/\&Igrave;/I/g; #		s/\&Igrave;/Ì/g;
		s/\&agrave;/a/g; #		s/\&agrave;/à/g;
		s/\&ograve;/o/g; #		s/\&ograve;/ò/g;
		s/\&egrave;/e/g; #		s/\&egrave;/è/g;
		s/\&ugrave;/u/g; #		s/\&ugrave;/ù/g;
		s/\&igrave;/i/g; #		s/\&igrave;/ì/g;
	}


	if( /&.{1,8}?;/ )
	{
		print STDERR "\nUnknown html char: $& on line $linenum\n";
	}

	#Skip blank lines (all blank lines
	next if( not /[^ \t]/ );

	#Kill prefixed spaces.
	s/^ //;
	s/ $//;

	print $_ . " ";
}
