#!/usr/bin/perl

# Modules
use strict;
use Getopt::Long;
Getopt::Long::Configure('bundling');

# Functions
sub _syntax_err(@)
{
	my $msg = shift;
	print <<EOU;
 Err: $msg
 
 Syntax:
 -f [/path/to/file] -w [time in seconds] -c [time in seconds] -v

 -v option will cause the check to return UNKNOWN exit status in case of the file doesn't exists

 Information:
 This script will check the modification time of a file,
 If it is [time in seconds] older an error status will be generated according to the -w and -c arguments
 If the file doesn't exists no error will be generated
 Its primary purpose is to check that lock files doesn't exists for too much time
        
EOU
	exit(3);
}

# User input
my %opt;
my $result = GetOptions(\%opt,
	'file|f=s',
	'warn|w=i',
	'crit|c=i',
	'verify|v',
);

# Validate arguments
_syntax_err("Missing -f") unless defined $opt{'file'};
_syntax_err("Missing -w") unless defined $opt{'warn'};
_syntax_err("Missing -c") unless defined $opt{'crit'};
_syntax_err("-w can't be >= than -c") if ($opt{'warn'} >= $opt{'crit'});

# Variables
my $OK = 0;
my $WARNING = 1;
my $CRITICAL = 2;
my $UNKNOWN = 3;
my $status = $OK;
my $msg;
my $perf;

# Take mtime and systems's epoc if file exists
if( -f $opt{'file'})
{
	my $filestat = (stat($opt{'file'}))[9];
	my $epoc = time;
	my $timediff = $epoc - $filestat;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $timestamp = "$mday/$mon/$year $hour:$min:$sec";
	
	# Decide exit status
	if ($timediff < $opt{'warn'})
	{
		$msg = "OK: look's good";
		$status = $OK;
	}
	elsif ($timediff >= $opt{'warn'} && $timediff < $opt{'crit'})
	{
		$msg = "WARN: $opt{'file'} mtime is $timestamp";
		$status = $WARNING;
	}
	else
	{
		$msg = "CRIT: $opt{'file'} mtime is $timestamp";
		$status = $CRITICAL;
	}

	$perf = "mtime=$timediff"."s".";$opt{'warn'};$opt{'crit'}";
}
# If file doesn't exists exit OK nothing to check (or UNKNOWN in case of -v)
else
{
	if($opt{'verify'})
	{
	  $msg = "UNKNOWN: $opt{'file'} doesn't exists";
	  $perf = "mtime=0s;$opt{'warn'};$opt{'crit'}";
	  $status = $UNKNOWN;
	}
	else
	{
	  $msg = "OK: $opt{'file'} doesn't exists, nothing to check";
	  $perf = "mtime=0s;$opt{'warn'};$opt{'crit'}";
	  $status = $OK;
	}
}

# Exit
print "$msg | $perf\n";
exit($status);
