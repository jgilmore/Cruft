#!/usr/bin/perl
package lisplib;
use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw(dofifo $infifoname $outfifoname);
@EXPORT_OK   = qw(dofifo $infifoname $outfifoname);
%EXPORT_TAGS = ();

our ($fifodir)=('/home/jgilmore/lisp');
 
our ($infifoname,$outfifoname)=
	($fifodir.'/.lisp-infifo',$fifodir.'/.lisp-outfifo');

sub dofifo
{
	my ($name)=@_;
	unless( -p $name ){
		unlink($name);
		system('/bin/mknod',$name,'p');
		if( $? == -1) {
			die "mknod $name failed to execute ";
		}
		elsif( $? & 127 ){
			die "mknod $name killed with signal ".($?&127);
		}
		elsif(not ($? >> 8) == 0){
			die "mknod $name exited with value" . ($?>>8);
		}
	}
}

1;
