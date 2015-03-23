#!/usr/bin/env perl

#####################################
#####################################
### ______               _     =) ###
### | ___ \             | |       ###
### | |_/ / __ _  _ __  | |       ###
### |    / / _` || '_ \ | |       ###
### | |\ \| (_| || | | || |____   ###
### \_| \_|\__,_||_| |_|\_____/   ###
#####################################
#####################################

use strict;
use XML::Simple;

sub FSyntaxError {
	print "Syntax Error !\n";
	print "$0 [s|q] [absolute path to settings.sh] [hostname] [queue name]\n";
	print "s = Status of the exec hosts: check for Error status, and if he has a queue instance enabled\n";
	print "q = check via qrsh is the host accepts jobs (you can configure a queue for all the exec hosts with access list only to nagios for the sake of this check)\n\n";
	print "Example:\n";
	print "$0 q /path/to/settings.sh quad-8g1 nagios.q\n";
	print "$0 s /path/to/settings.sh quad-8g1 [queues,to,exclude]\n";
	exit(1);
}

# User Input
if($#ARGV < 2) {
        FSyntaxError;
}
my $check_type = shift(@ARGV);
my $sge_settings = shift(@ARGV);
my $sgeexecd = shift(@ARGV);


# General Settings
my $exit = 0;
my $perf;
my $msg;

if("$check_type" eq "q") {
	# Check via qrsh
	my $queue = shift(@ARGV);
	my $qrsh = `source $sge_settings ; qrsh -q $queue\@$sgeexecd hostname &> /dev/null ; echo \$?`;
	chomp($qrsh);
	if($qrsh != 0) {
		$exit = 2;
		$perf = "qrsh=0";
		$msg = "$queue\@$sgeexecd cant execute jobs";
	} else {
		$perf = "qrsh=1";
		$msg = "$queue\@$sgeexecd can execute jobs";
	}
} elsif("$check_type" eq "s") {
	# Check Host's queue instance Status
	my $queue_list_2_exclude = shift(@ARGV);
	my @queues2ex = split(',',$queue_list_2_exclude);
	my $queue_instances = 0;
	my $queue_instances_err = 0;
	$perf = "qstatus=1";
	my @qstat_out = split("\n",`source $sge_settings ; qhost -q -h $sgeexecd`); shift(@qstat_out);shift(@qstat_out);shift(@qstat_out);shift(@qstat_out);

	foreach my $line (@qstat_out) {
		my @cline = split(" ",$line);
		my $yes_exclude = 0;
		foreach my $q (@queues2ex) {
			if($q eq $cline[0]) {
				$yes_exclude++;
				last;
			}
		}
		
		if($yes_exclude == 0) {
			if($cline[3] =~ /E/) {
				$msg = "$msg $cline[0]\@$sgeexecd in Error status.";
				$queue_instances_err++;
			}	
			unless($cline[3] =~ /d/) {
				$queue_instances++;
			}
		}
	}
	
	if($queue_instances == 0 or $queue_instances_err > 0) {
		if($queue_instances_err > 0) {
			$perf = "qstatus=$queue_instances_err";
		} else {
			$perf = "qstatus=0";
		}
		if($queue_instances == 0) {
			$perf = "$perf qconfigured=0";
			$msg = "$msg $sgeexecd dont have any queue configured.";
		} else {
			$perf = "$perf qconfigured=$queue_instances";
		}
		$exit = 2;
	} else {
		$exit = 0;
		$msg = "$sgeexecd is OK";
		$perf = "qstatus=0 qconfigured=$queue_instances";
	}
} else {
	FSyntaxError;
}


# Display Message
if($exit == 0) {
	$msg = "OK: $msg";
} else {
	$msg = "Error: $msg";
}
print "$msg | $perf\n";
exit($exit);

