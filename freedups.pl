#!/usr/bin/perl
#Copyright 2002, William Stearns <wstearns@pobox.com>
#Released under the GPL.

#Code overview:
#
#	This program is given a set of directories to scan.  It uses the
#perl equivalent of find to stat all files in those directories; these
#files are loaded into the %InodesOfSize, %InodeOfFile, and
#%FilesOfInode hashes.
#
#	We now need to find Inodes that might be linkable with each
#other.  For a given size, if we only know of one inode that large, we
#can immediately forget about it since there's nothing we could possibly
#link it to (solitary inodes).  We then walk through the remaining
#inodes, starting with the largest.  For every pair of same-sized inodes,
#we check to see if that pair is linkable; if so, we pick one inode to
#stay as is (the more sparse, older, or already more heavily linked
#inode), and hardlink all filenames associated with the other inode to
#it.

#FIXME - race where file replaced long after stat.
#FIXME - on ctrl-C perhaps write out cache.
#FIXME - Progress headers
#FIXME - support minsize and maxsize range
#FIXME - careful walk through bash version to compare.
#FIXME - print stats on which criteria used to decide who links to who
#FIXME - check all variable uses to make sure we're not printing packed data
#FIXME - This app currently requires full paths - make it more gracefully handle relative?
#FIXME - check debugs
#FIXME - hand down filename to IndexFile, don't use basename
#FIXME - reduce number of stats?

use strict;
use File::Find ();
use File::Compare;
use File::Basename;

use File::stat;
use Digest::MD5;
use IO::File;

use Getopt::Long;

use POSIX qw(getcwd);

use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;

use constant MD5SUM_MIN_SAVE_SIZE => 8193;	#Only files this size and larger will have their md5sums saved to the cache file.  Any non-empty file will have its checksum saved in ram during a run; this only affects the save at the end of a run.

my $FreedupsVer="0.6.14";

my %KnownMd5sums = ( );			#Key is packed device, inode, crucial characteristics, value is md5sum of that inode.  On-disk cache is loaded into this and saved to from this.
my %NewMd5sums = ( );			#known holds the sums loaded from the cache; these obviously don't need to be rewritten back out.  New holds new ones that need to be written out at the end.

#The following hashes store info about files in the requested directory trees only; there could be others in the filesystem that freedups wasn't asked to index.
my %InodesOfSize;			#All the inodes of the size key.  This is a hash whose values are arrays.
my %InodeOfFile;			#Provides the InodeSpec of the Filename key (this is loaded very late now; it only holds the files and InodeSpecs for the files of the size currently being processed).
my %FilesOfInode;			#The filenames associated with the inode key.  This is a hash whose values are arrays.

my @PathIndex;
my @FileOf;
my @Paths;

my $CurrentIndex = 0;

my $NumSpecs = 0;			#Number of command line directory/file specs in which to search for candidate files.
my $CachedSums = 0;			#How many checksums we were able to pull from cache.
my $FromDiskSums = 0;			#How many checksums we had to pull from media.
my $SpaceSaved = 0;			#How many bytes saved.  Takes into account whether we're removing the last link to the file or other links exist.
my $EstimatedSpaceSaved = 0;		#How much space we would have saved if -a had been on.
#my $SolitaryInodeSizes = 0;		#Sizes for which there was only one inode.	#We no longer know this.
#my $MultipleInodeSizes = 0;		#Sizes for which there was more than one inode.	#We no longer know this either.
my $UniqueFilesScanned = 0;		#How many unique filenames we inspected.
my $UniqueInodesScanned = 0;		#How many unique inodes encountered during initial scan.
my $LastSizeLinked = 0;			#For progress, what's the last linked inode size.
my $InternalChecks = 0;			#Used during development for additional internal checks.
my $DroppedFilenames = 0;		#How many filenames were discarded because there were already $MaxFiles filenames for that inode.
my $DiscardedSmallSums = 0;		#Checksums we threw away at the save step because they were too small.

#User options:
#1 (true) or 0 (false)
my $ActuallyLink = 0;			#Actually link the files.  Otherwise, just report on potential savings and preload the md5sum cache.
my $CacheFile = "$ENV{HOME}/md5sum-v1.cache";	#Private file that holds the inode=md5sum cache between runs.  Must be created before program runs.
my $DatesEqual = 0;			#Only link files if their modification times are identical
my $FileNamesEqual = 0;			#Require that the two (pathless) filenames be equal before linking.
my $Help = 0;				#Show help
my $MaxFiles = 0;			#Maximum files to remember for a given inode; reduce to save ram.
my $MinSize = 0;			#Files _larger_ than this many bytes are considered for linking.  0 byte files are _never_ considered.
#I've found at least one program bug (don't use == with alphanumeric md5sums) with Paranoid.  I recommend leaving it on for now.
my $Paranoid = 1;			#Set to 1 to force a strict compare just before linking.
my $Verbosity = 1;			#0 = Just intro and stats, 1 = Normal, 2 = some debugging, 3 = Show me everything!  #FIXME - prompts have not been strictly checked.



#sub RealName {
#	my $FileIndex = shift;
#	return "$Paths[$PathIndex[$FileIndex]]/$FileOf[$FileIndex]";
#}


sub Debug {
	my $DebugLevel = shift;
	if ($Verbosity >= $DebugLevel) {
		my $DebugString = shift;
		print "$DebugString\n";
	}
} #End sub Debug


#FIXME - new storage format
sub LoadSums {
#Load %KnownMd5sums from cache file
	my $cache_filename = shift;

	undef $!;
	if (my $cache_read_fh = IO::File->new($cache_filename, O_RDONLY)) {	# |O_CREAT not used, security risk
		my $loaded_pairs = 0;
		undef $!;

		while (defined(my $cache_line = <$cache_read_fh>)) {			#process one cache entry from local file.
			chomp $cache_line;
			my ($cache_inodespec, $cache_md5sum) = split(/=/, $cache_line, 2);
			#Debug 4, "Read \"$cache_inodespec,$cache_md5sum\".";
			if ($cache_md5sum ne '') {
				my ($Tdev, $Tino, $Tmode, $Tuid, $Tgid, $Tsize, $Tmtime, $Tctime) = split(/\//, $cache_inodespec);
				$KnownMd5sums{pack("SLSSSLLL",$Tdev,$Tino,$Tmode,$Tuid,$Tgid,$Tsize,$Tmtime,$Tctime)} = pack("H32", $cache_md5sum);
				$loaded_pairs++;
			#} else {
			#	Debug 3, "Blank md5sum read for $cache_inodespec."; 
			}
		}
		close cache_read_fh;
		#Debug 2, "Initial load: loaded $loaded_pairs cached KnownMd5sums from $cache_filename.";
	} else {	#Warn about missing or unreadable cache file.
		Debug 1, "Local cache file $cache_filename unavailable or unreadable.  Create it (with   'touch $cache_filename'   perhaps) if it's not there and check permissions, please: $!";
	} #End of load cache file entries
} #End sub LoadSums


#FIXME - new storage format
sub SaveSums {
#Save %NewMd5sums to cache file
	my $cache_filename = shift;
	if (my $cache_write_fh = IO::File->new("$cache_filename", O_WRONLY|O_APPEND)) { # |O_CREAT not used, security risk.
		foreach my $key (keys %NewMd5sums) {
			if ($NewMd5sums{$key} ne '') {
				my ($Tdev, $Tino, $Tmode, $Tuid, $Tgid, $Tsize, $Tmtime, $Tctime) = unpack("SLSSSLLL", $key);
				if ($Tsize >= MD5SUM_MIN_SAVE_SIZE) {
					print $cache_write_fh "$Tdev/$Tino/$Tmode/$Tuid/$Tgid/$Tsize/$Tmtime/$Tctime=", unpack("H32", $NewMd5sums{$key}), "\n";
				} else {
					$DiscardedSmallSums++;
				}
			#} else {
			#	Debug 3, "Blank md5sum not written for $key."; 
			}
		}
		close $cache_write_fh;
	} else {	#Warn about missing or unwritable cache file.
		Debug 1, "Local cache file $cache_filename unavailable or unwritable for storing new entries.  Create it (with   'touch $cache_filename'   perhaps) if it's not there and check permissions, please: $!.";
	}
} #End sub SaveSums


sub MD5SumOf {
#This returns the md5sum of a given file.  stat(file) returns the Inode
#info we need to pull the cached md5sum from %KnownMd5sums or we pull
#the checksum from disk and save it in %KnownMd5sums and %NewMd5sums (and hence, in the
#md5sum cache file) for future use.
	my $SumIndex = shift or die "No file specified in MD5SumOf: $!";
	my $SumFile = "$Paths[$PathIndex[$SumIndex]]/$FileOf[$SumIndex]";

	my $InodeSpec;

	if (! defined($InodeOfFile{$SumIndex})) {
		my $sb = stat($SumFile);
		$InodeOfFile{$SumIndex}=pack("SLSSSLLL",$sb->dev, $sb->ino, $sb->mode, $sb->uid, $sb->gid, $sb->size, $sb->mtime, $sb->ctime);
		if ($InternalChecks) {
			my ($Tdev, $Tino, $Tmode, $Tuid, $Tgid, $Tsize, $Tmtime, $Tctime) = unpack("SLSSSLLL", $InodeOfFile{$SumIndex});
			die $sb->dev . " ne " . $Tdev . ", exiting" if ($sb->dev ne $Tdev);
			die $sb->ino . " ne " . $Tino . ", exiting" if ($sb->ino ne $Tino);
			die $sb->mode . " ne " . $Tmode . ", exiting" if ($sb->mode ne $Tmode);
			die $sb->uid . " ne " . $Tuid . ", exiting" if ($sb->uid ne $Tuid);
			die $sb->gid . " ne " . $Tgid . ", exiting" if ($sb->gid ne $Tgid);
			die $sb->size . " ne " . $Tsize . ", exiting" if ($sb->size ne $Tsize);
			die $sb->mtime . " ne " . $Tmtime . ", exiting" if ($sb->mtime ne $Tmtime);
			die $sb->ctime . " ne " . $Tctime . ", exiting" if ($sb->ctime ne $Tctime);
		}
	}
	$InodeSpec = $InodeOfFile{$SumIndex};

	#if (defined($NewMd5sums{$InodeSpec})) {
	#	$CachedSums++;
	#	####$SumToReturn = $NewMd5sums{$InodeSpec};
	#	Debug 3, "Checksum came from new cache.";		#Add in ...unpack("SLSSSLLL", $InodeSpec)... perhaps later
	#} els
	if (defined($KnownMd5sums{$InodeSpec})) {
		$CachedSums++;
		#Debug 3, "Checksum came from known cache.";		#Add in ...unpack("SLSSSLLL", $InodeSpec)... perhaps later
	} else {
		$FromDiskSums++;
		open(FILE, $SumFile) or die "Can't open '$SumFile': $!";
		binmode(FILE);
		#$KnownMd5sums{$InodeSpec} = Digest::MD5->new->addfile(*FILE)->hexdigest;
		my $TempSum = Digest::MD5->new->addfile(*FILE)->hexdigest;
		#FIXME Chained ... = ... = ...?
		$KnownMd5sums{$InodeSpec} = pack("H32", $TempSum);
		$NewMd5sums{$InodeSpec} = pack("H32", $TempSum);
		if ($InternalChecks) {
			if (unpack("H32", $KnownMd5sums{$InodeSpec}) ne $TempSum) {
				die "Unpack failure " . $KnownMd5sums{$InodeSpec} . " ne " . $TempSum . ", exiting.";
			}
		}
		#Debug 3, "Checksum came from physical disk.";		#add in ...unpack("SLSSSLLL", $InodeSpec)... perhaps later
		#Do I need to explicitly close here?
	}
	#Debug 3, "File: $SumFile, Sum: " . unpack("H32", $KnownMd5sums{$InodeSpec}) . ".";
	return $KnownMd5sums{$InodeSpec};
} #End sub MD5SumOf


sub IndexFile {
	$CurrentIndex++;

	my $OneFile = shift;
	$FileOf[$CurrentIndex] = shift;

	my $OnePath = dirname($OneFile);

	if ($OnePath eq $Paths[$#Paths]) {
		#print '!';
		$PathIndex[$CurrentIndex] = $#Paths;
	} else {
		$PathIndex[$CurrentIndex] = $#Paths + 1;
		$Paths[$#Paths + 1] = $OnePath;
	}
	#Because perl's find function appears to walk the directories sequentially, there's no point in looking at any but the last
	#directory in the stack.
	#} else {
	#	#print '^';
	#	foreach my $PathWalk (reverse (1..$#Paths)) {
	#		#print "ZZ Comparing $OnePath to $PathWalk : $Paths[$PathWalk].\n";
	#		if ($OnePath eq $Paths[$PathWalk]) {
	#			#print '.';	#Never get here; we never go back to an old directory.
	#			#print "ZZ found path at $PathWalk.\n";
	#			$PathIndex[$CurrentIndex] = $PathWalk;
	#			$Done = 1;
	#			last;
	#		}
	#	}
	#}

	#This was the simple approach that just made a new path entry for each file.
	#$Paths[$CurrentIndex] = $OnePath;
	#$PathIndex[$CurrentIndex] = $CurrentIndex;

	#print "ZZ $OneFile ZZ $OnePath ZZ $FileOf[$CurrentIndex] YY $Paths[$PathIndex[$CurrentIndex]]/$FileOf[$CurrentIndex]\n";
	#return 0;

	my $sb = stat($OneFile);
	if (defined $sb) {
		my $InodeSpec=pack("SLSSSLLL",$sb->dev, $sb->ino, $sb->mode, $sb->uid, $sb->gid, $sb->size, $sb->mtime, $sb->ctime);
		#Quick note - InodesOfSize _used_ to be all the inodes of a gizen size, now it's all the inodes of a given equivalence class.
		my $EquivClass;
		if ($DatesEqual) {
			$EquivClass=pack("LSSSL",$sb->size, $sb->uid, $sb->gid, $sb->mode, $sb->mtime);
		} else {
			$EquivClass=pack("LSSS",$sb->size, $sb->uid, $sb->gid, $sb->mode);
		}
		if ($InternalChecks) {
			my ($Tdev, $Tino, $Tmode, $Tuid, $Tgid, $Tsize, $Tmtime, $Tctime) = unpack("SLSSSLLL", $InodeSpec);
			die $sb->dev . " dev ne " . $Tdev . ", exiting" if ($sb->dev ne $Tdev);
			die $sb->ino . " ino ne " . $Tino . ", exiting" if ($sb->ino ne $Tino);
			die $sb->mode . " mode ne " . $Tmode . ", exiting" if ($sb->mode ne $Tmode);
			die $sb->uid . " uid ne " . $Tuid . ", exiting" if ($sb->uid ne $Tuid);
			die $sb->gid . " gid ne " . $Tgid . ", exiting" if ($sb->gid ne $Tgid);
			die $sb->size . " size ne " . $Tsize . ", exiting" if ($sb->size ne $Tsize);
			die $sb->mtime . " mtime ne " . $Tmtime . ", exiting" if ($sb->mtime ne $Tmtime);
			die $sb->ctime . " ctime ne " . $Tctime . ", exiting" if ($sb->ctime ne $Tctime);
		}

		#Check uniqueness by scanning FilesOfInode
		my $FileAlreadyInFOI = 0;	#False
		foreach my $ExistingIndex (@{$FilesOfInode{$InodeSpec}}) {
			if ($OneFile eq "$Paths[$PathIndex[$ExistingIndex]]/$FileOf[$ExistingIndex]") {
				$FileAlreadyInFOI = 1;
				last;	#exit foreach now
			}
		}
		if (! $FileAlreadyInFOI) {
			#Already in there
		#	Debug 3, "  NOT adding $OneFile to FilesOfInode, already there.";
		#} else {
			#Debug 3, "  Adding $OneFile to FilesOfInode.";

			$UniqueFilesScanned++;
			#if (defined($FilesOfInode{$InodeSpec})) {

#FIXME (3x) handle and allow maxfiles=0
			if ($#{$FilesOfInode{$InodeSpec}} >= $MaxFiles) {
				$DroppedFilenames++;
			} else {
				push @{$FilesOfInode{$InodeSpec}}, $CurrentIndex;
			}

			#} else {
			#	$FilesOfInode{$InodeSpec} = [ $CurrentIndex ];
			#}

			if (defined($InodesOfSize{$EquivClass})) {
				#Check to see if $InodeSpec already in $InodesOfSize{$EquivClass}
				my $InodeAlreadyInIOS = 0;	#False
				foreach my $OneInodeSpec (@{$InodesOfSize{$EquivClass}}) {
					if ($OneInodeSpec eq $InodeSpec) {
						$InodeAlreadyInIOS = 1;
						last;	#exit foreach loop now.
					}
				}
				if (! $InodeAlreadyInIOS) {
					#Already in there
				#	Debug 3, "  NOT Adding $InodeSpec to InodesOfSize, already there.";
				#} else {
					$UniqueInodesScanned++;
					#Debug 3, "  Adding $InodeSpec to InodesOfSize";
					#Old approach - next line - was to just add the new inode to InodesOfSize and come back to scan InodesOfSize later.
					#push @{$InodesOfSize{$EquivClass}}, $InodeSpec;

					#Old approach recreated the @{$InodesOfSize{$EquivClass}} array on every inode.
					#Now we'll just walk through it with a counter.
					#my @CurrentInodes = @{$InodesOfSize{$EquivClass}};
					#@{$InodesOfSize{$EquivClass}} = ( );	#Start with a fresh list; we'll pull in the inodes one by one. [ ] instead?
		
					my $Done = 0;
					#Now we compare InodeSpec to each of the existing InodesOfSize (stopping when we find a match) right now to see if there's a match.
					foreach my $InIndex (0..$#{$InodesOfSize{$EquivClass}}) {
						#my $OneExistingInode = @{$InodesOfSize{$EquivClass}}[$InIndex];
						my $DidWeLink = CheckForLinkableInodes(@{$InodesOfSize{$EquivClass}}[$InIndex], $InodeSpec);
						if ($DidWeLink == 0) {
							#No link was performed.  Keep the Existing Inode in the list, keep going to see if any of the others match.
							#push @{$InodesOfSize{$EquivClass}}, $OneExistingInode;
						} elsif ($DidWeLink == 1) {
							#Left inode kept, right inode linked to it.  Keep the Existing Inode in the list, stop searching.
							#push @{$InodesOfSize{$EquivClass}}, $OneExistingInode;
							$Done = 1;
							last;
						} elsif ($DidWeLink == 2) {
							#Right inode kept, left inode was linked to it.  Put the new Inode in the new list, stop searching.
							@{$InodesOfSize{$EquivClass}}[$InIndex] = $InodeSpec;
							#push @{$InodesOfSize{$EquivClass}}, $InodeSpec;
							$Done = 1;
							last;
						} else {
							die "Unexpected return value ($DidWeLink) from CheckForlinkablenodes";
						}
					}
					#OK, we compared $InodeSpec to all the existing inodes of that size; no match.
					#We need to add this to the list so that we can compare it to future inodes.
					#Bill completely failed to notice this oversight; my _sincere_ thanks to 
					#Martin Sheppard for noticing the problem, debugging it, and sending in a patch.
					if (!$Done) {
						push @{$InodesOfSize{$EquivClass}}, $InodeSpec;
					}
				}
			} else {
				$UniqueInodesScanned++;
				#Debug 4, "  Initial add $InodeSpec to InodesOfSize";
				$InodesOfSize{$EquivClass} = [ $InodeSpec ];
			}
		}
	} else {
		Debug 2, "Can't stat $OneFile: $!";
	}
} #End sub IndexFile


#Function provided by find2perl ... -type f -a -size +3366c
sub wanted {
	my ($dev,$ino,$mode,$nlink,$uid,$gid);

	(($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) &&
	-f _ &&
	(int(-s _) > $MinSize) &&
	IndexFile $File::Find::name, $_;
	#IndexFile getcwd, $_;
	#$File::Find::name is the full path and file name
	#$File::Find::dir is the path to the file, but it's not a complete path
	#$_ is the current filename
} #End sub wanted


sub LinkFiles {
	#FIXME - this modifies %FilesOfInode and $InodeOfFile.  Check to see if upper layers care. (partially checked)
	#clean up? %md5sums{InodeSpec} - remove inode entry on last unlink.  (DONE)
	#clean up? %InodeOfFile{Filename} - Reset to new inode after hardlink and reinstate Identical Inode warning. (DONE)
	#clean up? %FilesOfInode{InodeSpec} - Move file from old inode to new (DONE)
	my $BaseIndex = shift;	#Index of file which will stay as is
	my $LinkIndex = shift;	#Index of file which will end up as a link to BaseFile

	my $BaseFile = "$Paths[$PathIndex[$BaseIndex]]/$FileOf[$BaseIndex]" ;	#Filename of file which will stay as is
	my $LinkName = "$Paths[$PathIndex[$LinkIndex]]/$FileOf[$LinkIndex]" ;	#Filename which will end up as a link to BaseFile

	if ( ($FileNamesEqual) && ($FileOf[$BaseIndex] ne $FileOf[$LinkIndex]) ) {
		#Debug 3, "$BaseFile and $LinkName have different filenames at the end, not linking.";
		return;
	}

	my $TempSsb=stat($LinkName);
	my $EquivClass;
	if ($DatesEqual) {
		$EquivClass=pack("LSSSL",$TempSsb->size, $TempSsb->uid, $TempSsb->gid, $TempSsb->mode, $TempSsb->mtime);
	} else {
		$EquivClass=pack("LSSS",$TempSsb->size, $TempSsb->uid, $TempSsb->gid, $TempSsb->mode);
	}
	#FIXME - moves this and the clear at the end outside of the loop in LinkInodes?
	#Here we load $InodeOfFile{} with _just_ the files/inodes of the current size, pulling from FilesOfInode{InodesOfSize}
	#I think I won't clear it at the moment.
	#%InodeOfFile = ( );
	foreach my $InodeToIndex (@{$InodesOfSize{$EquivClass}}) {
		foreach my $FileToIndex (@{$FilesOfInode{$InodeToIndex}}) {
			$InodeOfFile{$FileToIndex} = $InodeToIndex;
		}
	}
	if ($Paranoid) {
		#Check that file hasn't been modified since it was stat'd right after find.  I'm aborting the program if changes occur; that tends to point
		#to a file that's actively being modified.  This shouldn't happen.
		#Note that the following are duplicate checks; the file has already passed these once.  Failing now means that file(s) is/are actively being
		#changed under us.
		my $Fsb=stat($BaseFile);
		my $Ssb=stat($LinkName);
		if (!(-e "$BaseFile")) {
			die ("LinkFile: $BaseFile no longer exists or is not a file anymore. Exiting.");
		}
		if (!(-e "$LinkName")) {
			die ("LinkFile: $LinkName no longer exists or is not a file anymore. Exiting.");
		}
		if ( ! ( ($Fsb->mode == $Ssb->mode) && ($Fsb->uid == $Ssb->uid) && ($Fsb->gid == $Ssb->gid) && ($Fsb->size == $Ssb->size) ) ) {
			Debug 0, "File1: $InodeOfFile{$BaseIndex}, Associated files: @{$FilesOfInode{$InodeOfFile{$BaseIndex}}}, md5sum: $KnownMd5sums{$InodeOfFile{$BaseIndex}}.";
			Debug 0, "File2: $InodeOfFile{$LinkIndex}, Associated files: @{$FilesOfInode{$InodeOfFile{$LinkIndex}}}, md5sum: $KnownMd5sums{$InodeOfFile{$LinkIndex}}.";
			die ("LinkFile: paranoid stat checks failed! Please check failure in linking $BaseFile and $LinkName. Exiting.");
		}
		if (compare("$BaseFile","$LinkName") != 0) {	#Byte for byte compare not equal
			Debug 0, "File1: $InodeOfFile{$BaseIndex}, Associated files: @{$FilesOfInode{$InodeOfFile{$BaseIndex}}}, md5sum: $KnownMd5sums{$InodeOfFile{$BaseIndex}}.";
			Debug 0, "File2: $InodeOfFile{$LinkIndex}, Associated files: @{$FilesOfInode{$InodeOfFile{$LinkIndex}}}, md5sum: $KnownMd5sums{$InodeOfFile{$LinkIndex}}.";
			die ("LinkFile: paranoid file comparison failed for $BaseFile and $LinkName, please check why.  Exiting.");
		}
		$Fsb=stat($BaseFile);	#Refresh stat blocks in case either changed during file compare.
		$Ssb=stat($LinkName);
		if ( ! ( ($Fsb->mode == $Ssb->mode) && ($Fsb->uid == $Ssb->uid) && ($Fsb->gid == $Ssb->gid) && ($Fsb->size == $Ssb->size) ) ) {
			Debug 0, "File1: $InodeOfFile{$BaseIndex}, Associated files: @{$FilesOfInode{$InodeOfFile{$BaseIndex}}}, md5sum: $KnownMd5sums{$InodeOfFile{$BaseIndex}}.";
			Debug 0, "File2: $InodeOfFile{$LinkIndex}, Associated files: @{$FilesOfInode{$InodeOfFile{$LinkIndex}}}, md5sum: $KnownMd5sums{$InodeOfFile{$LinkIndex}}.";
			die ("LinkFile: Second paranoid stat checks failed! Please check failure in linking $BaseFile and $LinkName. Exiting.");
		}
		#If the user asked to check mtime and the timestamps are not equal, something's wrong
		if ( ($DatesEqual) && ($Fsb->mtime != $Ssb->mtime)  ) {
			Debug 0, "File1: $InodeOfFile{$BaseIndex}, Associated files: @{$FilesOfInode{$InodeOfFile{$BaseIndex}}}, md5sum: $KnownMd5sums{$InodeOfFile{$BaseIndex}}.";
			Debug 0, "File2: $InodeOfFile{$LinkIndex}, Associated files: @{$FilesOfInode{$InodeOfFile{$LinkIndex}}}, md5sum: $KnownMd5sums{$InodeOfFile{$LinkIndex}}.";
			die ("LinkFile: mtime paranoid check failed! Please check failure in linking $BaseFile and $LinkName. Exiting.");
		}
		#Debug 2, "        Paranoid checks passed for $BaseFile and $LinkName.";
	}

	#Actually link and check return code
	if ($ActuallyLink) {
		my $Ssb=stat($LinkName);	#Have to grab stat before link or else you're looking at nlinks of the merged inode.
		#FIXME - how to handle case where LinkName unlinked but link call fails?
		if (unlink($LinkName) && link($BaseFile,$LinkName)) {
			Debug 1, "        linked $BaseFile $LinkName";
			if ($Ssb->nlink == 1) {
				#undef LinkName md5sum here, we just removed the last dentry pointing at the file.
				undef $KnownMd5sums{$InodeOfFile{$LinkIndex}};
				undef $NewMd5sums{$InodeOfFile{$LinkIndex}};
				$SpaceSaved += $Ssb->size;
			}
			#Add $LinkIndex to the list of files on the same inode as $BaseIndex
			if ($#{$FilesOfInode{$InodeOfFile{$BaseIndex}}} >= $MaxFiles) {
				$DroppedFilenames++;
			} else {
				push @{$FilesOfInode{$InodeOfFile{$BaseIndex}}}, $LinkIndex;
			}

#FIXME Should/could we strip the ProcessInodesOfSize::$Tail directly instead?  Not sure it would influence the link.
#Perhaps ProcessInodesOfSize could use a hand crafted walk through an array (that this routine could modify directly) instead?
			#Strip $LinkIndex from $FilesOfInode{$InodeOfFile{$LinkIndex}}
			my @TempFiles = @{$FilesOfInode{$InodeOfFile{$LinkIndex}}};
			if ($#TempFiles == -1) {
				die "Empty FOI-IOF array for $LinkIndex, $InodeOfFile{$LinkIndex}, shouldn't happen.";
			} elsif ($#TempFiles == 0) {
				if ( ($Paranoid) && ($FilesOfInode{$InodeOfFile{$LinkIndex}}[0] ne $LinkIndex) ) {
					die "Single Element list $FilesOfInode{$InodeOfFile{$LinkIndex}}[0] doesn't match $LinkIndex.";
				}
				#Only a single element, undef it
				undef $FilesOfInode{$InodeOfFile{$LinkIndex}};
			} else {
				#At least 2 array elements
				undef $FilesOfInode{$InodeOfFile{$LinkIndex}};	#Start fresh
				foreach my $AFileIndex (@TempFiles) {
					if ($AFileIndex ne $LinkIndex) {
						#if (defined($FilesOfInode{$InodeOfFile{$LinkIndex}})) {
							push @{$FilesOfInode{$InodeOfFile{$LinkIndex}}}, $AFileIndex;
						#} else {
						#	$FilesOfInode{$InodeOfFile{$LinkIndex}} = [ $AFileIndex ];
						#}
					}
				}
			}

			#Setting the correct Inode for this file must come after the above.
			$InodeOfFile{$LinkIndex}=$InodeOfFile{$BaseIndex};
		} else {
			Debug 1, "        Failed to link $BaseFile $LinkName";
		}
	} else {
		Debug 1, "        Would have linked $BaseFile $LinkName";
	}

	##Clear InodeOfFile entirely as we're done with this file size for the moment.
	%InodeOfFile = ( );
} #End sub LinkFiles


sub LinkInodes {
	my $FirstInode = shift;
	my $SecondInode = shift;
	my $PreferredInode;		#Also the return value for this function.  1 means left hand inode kept, 
					#right linked to it, 2 means right kept, left linked to it.  Doesn't matter if no links 
					#are performed, some links are performed, or all links are performed, we just need to return
					#which inode is preferred.

	my @FirstFileindexes = @{$FilesOfInode{$FirstInode}};
	my @SecondFileindexes = @{$FilesOfInode{$SecondInode}};

	my $Fsb=stat("$Paths[$PathIndex[$FirstFileindexes[0]]]/$FileOf[$FirstFileindexes[0]]");
	my $Ssb=stat("$Paths[$PathIndex[$SecondFileindexes[0]]]/$FileOf[$SecondFileindexes[0]]");

	if (! defined($FirstFileindexes[0]))  {
		#Debug 3, "No fileindexes for $FirstInode, why?.";
		return;
	}
	if (! defined($SecondFileindexes[0])) {
		#Debug 3, "No fileindexes for $SecondInode, why?.";
		return;
	}

	#Show progress with file size display
	if ($LastSizeLinked != $Fsb->size) {
		$LastSizeLinked = $Fsb->size;
		Debug 1, " " . $Fsb->size;
	}

#Who links to who?  First, make the choice:
#If one of the inodes is a more sparse file, we link to that.  In the end that gives more space savings.
	if ($Fsb->blocks < $Ssb->blocks) {	#Link SecondFiles to more sparse FirstInode
		#Debug 3, "        First more sparse.";
#The files are stripped from FilesOfInode by LinkFiles one by one as they're processed.  That's OK.
		$PreferredInode = 1;
	} elsif ($Fsb->blocks > $Ssb->blocks) {
		#Debug 3, "        Second more sparse.";
		$PreferredInode = 2;
#Next, if one of the files is older (smaller modification time) link both to the older inode.
	} elsif ($Fsb->mtime > $Ssb->mtime) {	#First file newer, link it to Second
		#Debug 3, "        First newer.";
		$PreferredInode = 2;
	} elsif ($Ssb->mtime > $Fsb->mtime) {	#Second file newer, link it to First
		#Debug 3, "        Second newer.";
		$PreferredInode = 1;
#Finally, if they use the same amount of space on disk and have the same mtime, see if one has more links than the other and glue both to the inode with more links.
	} elsif ($Ssb->nlink > $Fsb->nlink) {	#Second inode has more hardlinks, link all firsts to it
		#Debug 3, "        Second more hardlinks.";
		$PreferredInode = 2;
#(If they have the same amount of links or the first has more links, we'll hit this case and simply link any second files to the first inode by default.)
	} else {
		#Debug 3, "        First more hardlinks or equal.";
		$PreferredInode = 1;
	}


#Second, actually perform the links (or at least record estimated savings, which needs to be done here at the inode level)
	if ($PreferredInode == 1) {
		#Get estimated space savings on dry run
		if ($ActuallyLink) {
			foreach my $OneSecondFileindex (@SecondFileindexes) {	#Link all second inode fileindexes to the preferred first inode
				LinkFiles $FirstFileindexes[0], $OneSecondFileindex;
			}
		} else {
			#Debug 4, "FirEstUpdate: " . @SecondFileindexes . "," . $Ssb->nlink;
			if (@SecondFileindexes == $Ssb->nlink) {
				$EstimatedSpaceSaved += $Ssb->size;		
			} elsif (@SecondFileindexes > $Ssb->nlink) {
				die @SecondFileindexes . " second filenames can't be larger than " . $Ssb->nlink . ", why is it?";
			}	#no savings, nothing to do if (@SecondFileindexes < $Ssb->nlink)
			foreach my $OneSecondFileindex (@SecondFileindexes) {	#Link all second inode fileindexes to the preferred first inode
				#This is a mini version of LinkFiles for ActuallyLink=no
				if ( ($FileNamesEqual) && ($FileOf[$FirstFileindexes[0]] ne $FileOf[$OneSecondFileindex]) ) {
					#Debug 3, "$Paths[$PathIndex[$FirstFileindexes[0]]]/$FileOf[$FirstFileindexes[0]] and $OneSecondFileindex have different filenames at the end, not linking.";
					return;
				} else {
					Debug 1, "        Would have linked $Paths[$PathIndex[$FirstFileindexes[0]]]/$FileOf[$FirstFileindexes[0]] $Paths[$PathIndex[$OneSecondFileindex]]/$FileOf[$OneSecondFileindex]";
				}
			}
		}
	} elsif ($PreferredInode == 2) {
		if ($ActuallyLink) {
			foreach my $OneFirstFileindex (@FirstFileindexes) {	#Link all first inode fileindexes to the preferred second inode
				LinkFiles $SecondFileindexes[0], $OneFirstFileindex;
			}
		} else {
			#Debug 4, "SecEstUpdate: " . @FirstFileindexes . "," . $Fsb->nlink;
			if (@FirstFileindexes == $Fsb->nlink ) {
				$EstimatedSpaceSaved += $Fsb->size;		
			} elsif (@FirstFileindexes > $Fsb->nlink ) {
				die @FirstFileindexes . " first fileindexes can't be larger than " . $Fsb->nlink . ", why is it?";
			}	#no savings, nothing to do if (@FirstFileindexes < $Fsb->nlink )
			foreach my $OneFirstFileindex (@FirstFileindexes) {	#Link all first inode fileindexes to the preferred second inode
				#This is a mini version of LinkFiles for ActuallyLink=no
				if ( ($FileNamesEqual) && ($FileOf[$SecondFileindexes[0]] ne $FileOf[$OneFirstFileindex]) ) {
					#Debug 3, $SecondFileindexes[0] . " and $OneFirstFileindex have different filenames at the end, not linking.";
					return;
				} else {
					Debug 1, "        Would have linked $Paths[$PathIndex[$SecondFileindexes[0]]]/$FileOf[$SecondFileindexes[0]] $Paths[$PathIndex[$OneFirstFileindex]]/$FileOf[$OneFirstFileindex]";
				}
			}
		}
	} else {
		die "Internal error, PreferredInode is $PreferredInode.";
	}
	return $PreferredInode;
} #End sub LinkInodes


sub CheckForLinkableInodes {
	my $FirstInode = shift;
	my $SecondInode = shift;
	my $DidWeLink = 0;		#Return value for this function.  0 means no link performed, 1 means left hand inode kept, 
					#right linked to it, 2 means right kept, left linked to it (1 and 2 have to come from LinkInodes).

	#FIXME - printing packed format
	#Debug 2, "    Comparing $FirstInode to $SecondInode";

	#Here we're using the file characteristics encoded in the InodeSpec to identify candidates for compare.  If Paranoid is turned on, we'll re-verify
	#all this just before linking.  Turning Paranoid off risks problems with files being modified under us or a checksum cache with invalid entries.
	my ($Fdev, $Fino, $Fmode, $Fuid, $Fgid, $Fsize, $Fmtime, $Fctime) = unpack("SLSSSLLL", $FirstInode);
	#Debug 4, "$Fdev, $Fino, $Fmode, $Fuid, $Fgid, $Fsize, $Fmtime, $Fctime";

	my ($Sdev, $Sino, $Smode, $Suid, $Sgid, $Ssize, $Smtime, $Sctime) = unpack("SLSSSLLL", $SecondInode);
	#Debug 4, "$Sdev, $Sino, $Smode, $Suid, $Sgid, $Ssize, $Smtime, $Sctime";

	if ($Fdev == $Sdev) {
		#Same device
		if ($Fino != $Sino) {
		#	Debug 2, "      Tried to link identical Inodes, should not have happened.";
		#} else {
			#Same device, different inodes.  Can we link them?
			if ( ($Fmode == $Smode) && ($Fuid == $Suid) && ($Fgid == $Sgid) && ($Fsize == $Ssize) ) {
				#Same device, different inodes, same base characteristics.  Check modification time if the user wanted it.
				#The following loosely translates to "Continue on with the link checks if the user didn't care or the files have the same time anyways."
				if ( (!($DatesEqual)) || ($Fmtime == $Smtime)  ) {
					#Same device, different inodes, same characteristics.  Checksums match?
					#Note - we can't check for FileNamesEqual here.  We'll leave that until we actually have filenames to compare and check
					#that in LinkFiles
					if (defined($FilesOfInode{$FirstInode}) && defined($FilesOfInode{$SecondInode})) {
						#@{$FilesOfInode{$FirstInode}}[0] is the first filename associated with $FirstInode
						#@{$FilesOfInode{$SecondInode}}[0] is the first filename associated with $SecondInode
						if ( MD5SumOf(@{$FilesOfInode{$FirstInode}}[0]) eq MD5SumOf(@{$FilesOfInode{$SecondInode}}[0]) ) {	#DO NOT use == for md5sums; the sum appears to overflow perl integers, or ignore chars perhaps
							#my $FirstSumDebug=MD5SumOf(@{$FilesOfInode{$FirstInode}}[0]);
							#my $SecondSumDebug=MD5SumOf(@{$FilesOfInode{$SecondInode}}[0]);
							#Debug 4, "Sum1: $FirstSumDebug, Sum2: $SecondSumDebug";
							#Debug 2, "      Identical, linking @{$FilesOfInode{$FirstInode}}[0] and @{$FilesOfInode{$SecondInode}}[0] and any other filenames.";
							$DidWeLink=LinkInodes $FirstInode, $SecondInode;
							if (($DidWeLink != 1) && ($DidWeLink != 2)) {
								die "Invalid return ($DidWeLink) from LinkInodes";
							}
						#} else {
						#	Debug 2, "      Checksums don't match.";
						}
					#} else {
					#	Debug 3, "      Ignoring stripped file.";
					} 
				#} else {
				#	Debug 2, "      Not linking, different mtimes and user specified DatesEqual.";
				}
			#} else {
			#	Debug 2, "      Can't hardlink, different attributes.";
			}
		}
	#} else {
	#	Debug 3, "      Different devices, no chance to link.";
	}		
	return $DidWeLink;
} #End sub CheckForLinkableInodes


#Start Main()
my $USAGEMSG = <<USAGE;
Usage freedups.pl [options]
Options (default value in parentheses; 1=Enabled, 0=Disabled):
  --actuallylink|-a		Actually link the files, otherwise, just report on potential savings and preload the md5sum cache. ($ActuallyLink)
  --cachefile=<cache file>	File that holds cached queries and responses ($CacheFile) *
  --datesequal|-d		Require that the modification dates and times be equal before linking ($DatesEqual)
  --filenamesequal|-f		Require that the two (pathless) filenames be equal before linking ($FileNamesEqual)
  --help|-h			This help message
  --mafiles			Maximum number of files to remember for a given inode, reduct to save memory ($MaxFiles)
  --minsize|-m=<minimum size>	Only consider files larger than this number of bytes ($MinSize)
  --paranoid|-p			Recheck all file stats and completely compare every byte of the files just before linking.  This should definitely be left on unless you are _positive_ that the md5 checksum cache is correct and there's no chance that files will be modified behind freedups' back. ($Paranoid)
  --quiet|-q			Show almost nothing; forces verbosity to 0.
  --verbose|-v			Show more detail (Default verbosity=$Verbosity)
* For security reasons, this file must be created before starting freedups or it will not be used at all.


Examples:
To report on what files could be linked under any kernel source trees and preload the md5sum cache, but not actually link them:
  freedups /usr/src/linux-*
To link identical files in those trees:
  freedups -a /usr/src/linux-*
To be more strict; the modification time and filename need to be equal before two files can be linked:
  freedups -a --datesequal=yes -f /usr/doc /usr/share/doc
Only link files with 1001 or more bytes.
  freedups --actuallylink=yes -m 1000 /usr/src/linux-* /usr/src/pcmcia-*
USAGE

#Load command line params.  Directories to be scanned are left in ARGV so we can pull them with shift in a moment.
die "$USAGEMSG" unless GetOptions(	'actuallylink|a!'	=> \$ActuallyLink,
					'cachefile=s'		=> \$CacheFile,
					'datesequal|d!'		=> \$DatesEqual,
					'filenamesequal|f!'	=> \$FileNamesEqual,
					'help|h'		=> \$Help,
					'maxfiles=i'		=> \$MaxFiles,
					'minsize|m=i'		=> \$MinSize,
					'paranoid|p!'		=> \$Paranoid,
					'quiet|q'		=> sub { $Verbosity = 0 },
					'verbose|v+'		=> \$Verbosity );

die "$USAGEMSG" if $Help;

if ($MaxFiles <= 0) {
	$MaxFiles=1
}

#Start main code
print "Freedups Version $FreedupsVer\n";
print "Options Chosen: ";
print "ActuallyLink " if $ActuallyLink;
print "DatesEqual " if $DatesEqual;
print "FileNamesEqual " if $FileNamesEqual;
#If Help set, we won't get this far
print "Paranoid " if $Paranoid;
print "None " if (!( ($ActuallyLink) || ($DatesEqual) || ($FileNamesEqual) || ($Paranoid) ));
print "Verbosity=$Verbosity ";
print "CacheFile=$CacheFile ";
print "MaxFiles=$MaxFiles ";
my $SmallestFileSize = $MinSize + 1;
print "MinSize=$MinSize (only consider files $SmallestFileSize bytes and larger) ";
undef $SmallestFileSize;
print "\n";

print "Starting to load md5 checksum cache from $CacheFile.\n";
LoadSums $CacheFile;	#Wait until we've verified the filespecs before loading the cache as this can take time.
print "Finished loading checksums from checksum cache.\n";

#Load dir specs from command line
while (my $OneSpec = shift) {
	Debug 1, "Starting to scan $OneSpec";
	#Check that it exists first
	if (-e "$OneSpec") {
		File::Find::find(\&wanted, $OneSpec);	#subroutine could also be written {wanted => \&wanted}
		#This calls IndexFile(the_found_filename) which puts file info into the inode and file arrays and as of 0.6.3 actually does _all_ the processing.
		$NumSpecs++
	} else {
		die "Could not find anything named $OneSpec, exiting.\n";
	}
}

if ($NumSpecs == 0) {
	die "$USAGEMSG\nNo directories or files specified, exiting.\n";
}

print "Finished processing inodes, appending new md5sums.\n";
SaveSums $CacheFile;
print "Finished saving md5sums.\n";

print "$NumSpecs file specs searched.\n";
print "$UniqueFilesScanned Unique files scanned.\n";
print "$UniqueInodesScanned Unique inodes scanned.\n";
print "$DroppedFilenames filenames were discarded because there were already $MaxFiles filenames for that inode.\n";
print "Cached checksums: $CachedSums, From disk checksums: $FromDiskSums.\n";
if ($ActuallyLink) {
	print "Space saved: $SpaceSaved\n";
} elsif ($EstimatedSpaceSaved == 0) {
	print "No space would have been saved.\n";
} else {
	print "Up to $EstimatedSpaceSaved bytes would have been saved.\n";
}
#print "$SolitaryInodeSizes file sizes for which there was a single inode.\n";		#We no longer know this
#print "$MultipleInodeSizes file sizes for which there was more than one inode.\n";	#nor this.
if ($DiscardedSmallSums >= 1) {
	print "Discarded $DiscardedSmallSums checksums of small files.\n";
}

