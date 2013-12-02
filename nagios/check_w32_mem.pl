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
use Net::SNMP;
my $stat;
my $msg;
my $perf;

### SNMP OIDs
###############
my $S_Mem_Total = ".1.3.6.1.2.1.25.2.2.0"; # Byte
my $S_Process_Mem_Util = ".1.3.6.1.2.1.25.5.1.1.2";

### Functions
###############

sub _create_session {
	my ($server, $comm) = @_;
	my $version = 1;
	my ($sess, $err) = Net::SNMP->session( -hostname => $server, -version => $version, -community => $comm);
	if (!defined($sess)) {
		print "Can't create SNMP session to $server\n";
		exit(1);
	}
	return $sess;
}

sub FSyntaxError {
	print "Syntax Error !\n";
	print "$0 -H [ip|dnsname] -C [snmp community] -w [warning value] -c [critical value]\n";
	print "To disable warning and critical values type 200 as the value";
	exit(3);
}

if($#ARGV != 7) {
        FSyntaxError;
}

### Gather input from user
#############################
my $switch;
my $community;
my $check_type;
my $warn;
my $crit;

while(@ARGV) {
	my $temp = shift(@ARGV);
	if("$temp" eq '-H') {
		$switch = shift(@ARGV);
	} elsif("$temp" eq '-C') {
		$community = shift(@ARGV);
	} elsif("$temp" eq '-w') {
		$warn = shift(@ARGV);
	} elsif("$temp" eq '-c') {
		$crit = shift(@ARGV);
	} else {
		FSyntaxError();
	}
}

if($warn > $crit) {
	print "Warning can't be larger then Critical: $warn > $crit\n";
	FSyntaxError();
}

# Establish SNMP Session
our $snmp_session = _create_session($switch,$community);

# Total Memory
my $R_Mem_Total = $snmp_session->get_request(-varbindlist => [$S_Mem_Total]);
my $Mem_Total = "$R_Mem_Total->{$S_Mem_Total}";

# Used Memory
my $R_proc_tbl = $snmp_session->get_table($S_Process_Mem_Util);
my $Mem_Used = 0;
foreach my $oid ( keys %$R_proc_tbl) {
# 	print "$oid\t$$R_proc_tbl{$oid}\n";
	$Mem_Used = $Mem_Used + $$R_proc_tbl{$oid};
}

# Free Memory
my $Mem_Free = $Mem_Total - $Mem_Used;
my $Mem_Free_P = int($Mem_Free / $Mem_Total * 100);

# Humen Readable
my $Mem_Total_H = int($Mem_Total / 1024);
my $Mem_Used_H = int($Mem_Used / 1024);
my $Mem_Free_H = int($Mem_Free / 1024);

# Calculate Exit Status
if($Mem_Free_P < $warn) {
	$stat = 0;
	$msg = "Memory: OK - Free Memory $Mem_Free_P%";
}  elsif($Mem_Free_P > $warn and $Mem_Free_P < $crit) {
	$stat = 1;
	$msg = "Memory: Warn - Free Memory $Mem_Free_P%";
} elsif($Mem_Free_P > $crit) {
	$stat = 2;
	$msg = "Memory: CRIT - Free Memory $Mem_Free_P%";
}

$perf = "total=$Mem_Total_H used=$Mem_Used_H";

print "$msg | $perf\n";
exit($stat);
