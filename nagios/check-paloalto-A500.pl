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
my $script_name = "check-paloalto-A500.pl";

### SNMP OIDs
###############
my $s_cpu_mgmt = '.1.3.6.1.2.1.25.3.3.1.2.1';
my $s_cpu_data = '.1.3.6.1.2.1.25.3.3.1.2.2';

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
# 	print "$0 -H [ip|dnsname] -C [snmp community] -t [temp|fan|ps|cpu|mem|module|freeint] -w [warning value] -c [critical value] -d [days]\n";
	print "$script_name\n";
	print "-H = Ip/Dns Name of the FW\n";
	print "-C = SNMP Community\n";
	print "-t = Check type (currently only cpu)\n";
	print "-w = Warning Value\n";
	print "-c = Critical Value\n";
	exit(3);
}

if($#ARGV != 9) {
        FSyntaxError;
}

### Gather input from user
#############################
my $switch;
my $community;
my $check_type;
my $warn = 0;
my $crit = 0;
my $int;

while(@ARGV) {
	my $temp = shift(@ARGV);
	if("$temp" eq '-H') {
		$switch = shift(@ARGV);
	} elsif("$temp" eq '-C') {
		$community = shift(@ARGV);
	} elsif("$temp" eq '-t') {
		$check_type = shift(@ARGV);
	} elsif("$temp" eq '-w') {
		$warn = shift(@ARGV);
	} elsif("$temp" eq '-c') {
		$crit = shift(@ARGV);
	} else {
		FSyntaxError();
	}
}

# Validate Warning
if($warn > $crit) {
	print "Warning can't be larger then Critical: $warn > $crit\n";
	FSyntaxError();
}

# Establish SNMP Session
our $snmp_session = _create_session($switch,$community);

### CPU ###
if($check_type eq "cpu") {	
	my $R_mgmt = $snmp_session->get_request(-varbindlist => [$s_cpu_mgmt]);
	my $mgmt = "$R_mgmt->{$s_cpu_mgmt}";
	my $R_data = $snmp_session->get_request(-varbindlist => [$s_cpu_data]);
	my $data = "$R_data->{$s_cpu_data}";
	
	if($mgmt > $crit or $data > $crit) {
		$msg = "CRIT: Mgmt - $mgmt, Data - $data";
		$stat = 2;
	} elsif($mgmt > $warn or $data > $warn) {
		$msg = "WARN: Mgmt - $mgmt, Data - $data";
		$stat = 1;
	} else {
		$msg = "OK: Mgmt - $mgmt, Data - $data";
		$stat = 0;
	}
	$perf = "mgmt=$mgmt;data=$data;$warn;$crit";

### Bad Syntax ###

} else {
	FSyntaxError();
}


print "$msg | $perf\n";
exit($stat);
