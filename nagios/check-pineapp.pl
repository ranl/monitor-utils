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
use lib "/path/to/nagios/libexec";
use utils qw($TIMEOUT %ERRORS);
use Net::SNMP;
use Getopt::Long;
Getopt::Long::Configure('bundling');

my $stat = $ERRORS{'OK'};
my $msg;
my $perf;
my $script_name = "check-pineapp.pl";

### SNMP OIDs
###############
# CPULOAD
my $snmp_pineapp_cpuload = '.1.3.6.1.4.1.19801.1.1.3';
my $snmp_pineapp_cpuload_1min = "$snmp_pineapp_cpuload.1.0";
my $snmp_pineapp_cpuload_5min = "$snmp_pineapp_cpuload.2.0";
my $snmp_pineapp_cpuload_15min = "$snmp_pineapp_cpuload.3.0";
# Services
my $snmp_pineapp_services = '.1.3.6.1.4.1.19801.2.1';
my $snmp_pineapp_services_smtp = "$snmp_pineapp_services.1.0";
my $snmp_pineapp_services_pop3 = "$snmp_pineapp_services.2.0";
my $snmp_pineapp_services_imap4 = "$snmp_pineapp_services.3.0";
my $snmp_pineapp_services_av = '.1.3.6.1.4.1.19801.2.5.1.0';
# Queue
my $snmp_pineapp_queues = "$snmp_pineapp_services.10";
my $snmp_pineapp_queues_in = "$snmp_pineapp_queues.1.0";
my $snmp_pineapp_queues_out = "$snmp_pineapp_queues.2.0";
my $snmp_pineapp_queues_high = "$snmp_pineapp_queues.3.1.0";
my $snmp_pineapp_queues_normal = "$snmp_pineapp_queues.3.2.0";
my $snmp_pineapp_queues_low = "$snmp_pineapp_queues.3.3.0";
my $snmp_pineapp_queues_total = "$snmp_pineapp_queues.3.4.0";
my $snmp_pineapp_averageProcessingTimePerMsg = ".1.3.6.1.4.1.19801.2.2.1.4.0";
# Misc 
my $snmp_pineapp_storage = '.1.3.6.1.4.1.19801.1.4.0';

### Functions
###############
sub _create_session(@) {
	my ($server, $comm) = @_;
	my $version = 1;
	my ($sess, $err) = Net::SNMP->session( -hostname => $server, -version => $version, -community => $comm);
	if (!defined($sess)) {
		print "Can't create SNMP session to $server\n";
		exit(1);
	}
	return $sess;
}

sub FSyntaxError($) {
	my $err = shift;
	print <<EOU;
  $err

     Syntax:
	 $script_name
	 -H = Ip/Dns Name of the Pineapp           -w = Warning Value
	 -C = SNMP Community                       -c = Critical Value
	 -T = Check type
	 
	 ## Check Types
	 SERVICES   - Check if smtp,imap4,pop3,av are up
	 CPULOAD    - CPU Load
	 DISK       - Check the storage status
	 MSGPERSEC  - Average Time in seconds of proccesing 1 Msg
	 INOUT      - Queue Inbound/Outbound status (in=+ out=-) (no -w -c)
	 QUEUE      - Queue Priority Status (-w and -c apply to total amount of msg in the queue)
EOU
	exit($ERRORS{'UNKNOWN'});
}

sub _get_oid_value(@) {
	my $sess = shift;
	my $local_oid = shift;
	my $r_return = $sess->get_request(-varbindlist => [$local_oid]);
	return($r_return->{$local_oid});
}

sub _clac_err_stat(@) {
	my $value = shift;
	my $value_type = shift;
	my $tmp_warn = shift;
	my $tmp_crit = shift;
	my $unit = shift;
	my $r_msg;
	my $r_stat;
	if($value <= $tmp_warn) {
		$r_stat = $ERRORS{'OK'};
		$r_msg = "OK: $value_type $value$unit";
	}  elsif($value > $tmp_warn and $value < $tmp_crit) {
		$r_stat = $ERRORS{'WARNING'};
		$r_msg = "WARN: $value_type $value$unit";
	} elsif($value >= $tmp_crit) {
		$r_stat = $ERRORS{'CRITICAL'};
		$r_msg = "CRIT: $value_type $value$unit";
	}
	return($r_msg,$r_stat);
}

### Gather input from user
#############################
my %opt;
$opt{'crit'} = 500;
$opt{'warn'} = 500;
my $result = GetOptions(\%opt,
	'host|H=s',
	'community|C=s',
	'check_type|T=s',
	'warn|w=f',
	'crit|c=f',
);

FSyntaxError("Missing -H")  unless defined $opt{'host'};
FSyntaxError("Missing -C")  unless defined $opt{'community'};
FSyntaxError("Missing -T")  unless defined $opt{'check_type'};
if($opt{'warn'} > $opt{'crit'}) {
	FSyntaxError("Warning can't be larger then Critical: $opt{'warn'} > $opt{'crit'}");
}

# Starting Alaram
alarm($TIMEOUT);

# Establish SNMP Session
our $snmp_session = _create_session($opt{'host'},$opt{'community'});

# Start Check !
### CPULOAD ###
if("$opt{'check_type'}" eq "CPULOAD") {
	my $check = $snmp_session->get_table($snmp_pineapp_cpuload);
	($msg,$stat) = _clac_err_stat($$check{$snmp_pineapp_cpuload_1min},$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "load1=$$check{$snmp_pineapp_cpuload_1min} load5=$$check{$snmp_pineapp_cpuload_5min} load15=$$check{$snmp_pineapp_cpuload_15min}";
### SERVICES ###
} elsif("$opt{'check_type'}" eq "SERVICES") {
	my %check = (
		'smtp' => _get_oid_value($snmp_session,$snmp_pineapp_services_smtp),
		'pop3' => _get_oid_value($snmp_session,$snmp_pineapp_services_pop3),
		'imap4' => _get_oid_value($snmp_session,$snmp_pineapp_services_imap4),
		'av' => _get_oid_value($snmp_session,$snmp_pineapp_services_av)
	);
	
	my $count = 0;
	foreach my $srv ( keys %check) {
		if($check{$srv} == 0 ){
			$msg = "$msg, $srv is down";
			$stat = $ERRORS{'CRITICAL'};
			$count++;
		}
	}
	
	if($count == 0) {
		$msg = "OK: All Services Ok !";
	} else {
		$msg = "CRIT: $msg";
	}
	
	$perf = "down_srv=$count";
### DISK ###
} elsif("$opt{'check_type'}" eq "DISK") {
	my $check = _get_oid_value($snmp_session,$snmp_pineapp_storage);
	if($check eq "OK") {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} $check";
		$perf = "disk_err=0";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} $check";
		$perf = "disk_err=1";
	}
### MSGPERSEC ###
} elsif("$opt{'check_type'}" eq "MSGPERSEC") {
	my $check = _get_oid_value($snmp_session,$snmp_pineapp_averageProcessingTimePerMsg);
	($msg,$stat) = _clac_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'},"sec");
	$perf = "msgPersec=$check\sec";
### INOUT ###
} elsif("$opt{'check_type'}" eq "INOUT") {
	my $in = _get_oid_value($snmp_session,$snmp_pineapp_queues_in);
	my $out = _get_oid_value($snmp_session,$snmp_pineapp_queues_out);
	$msg = "OK: $opt{'check_type'} (Preformance Only)";
	$perf = "in=$in\msg out=-$out\msg";
### QUEUE ###
} elsif("$opt{'check_type'}" eq "QUEUE") {
	my $high = _get_oid_value($snmp_session,$snmp_pineapp_queues_high);
	my $normal = _get_oid_value($snmp_session,$snmp_pineapp_queues_normal);
	my $low = _get_oid_value($snmp_session,$snmp_pineapp_queues_low);
	my $total = _get_oid_value($snmp_session,$snmp_pineapp_queues_total);
	($msg,$stat) = _clac_err_stat($total,$opt{'check_type'},$opt{'warn'},$opt{'crit'},"msg");
	$perf = "total=$total\msg low=$low\msg normal=$normal\msg high=$high\msg";
} else {
	FSyntaxError("$opt{'check_type'} invalid parameter !");
}


print "$msg | $perf\n";
exit($stat);
