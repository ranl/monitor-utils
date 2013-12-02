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

my $stat = 0;
my $msg;
my $perf;
my $script_name = "check-juniper-vpn.pl";

### SNMP OIDs
###############
# IVE
my $snmp_juniper_ive = '.1.3.6.1.4.1.12532';
my $snmp_juniper_logFullPercent = "$snmp_juniper_ive.1.0";
my $snmp_juniper_WebUsers = "$snmp_juniper_ive.2.0";
my $snmp_juniper_MailUsers = "$snmp_juniper_ive.3.0";
my $snmp_juniper_MeetingUsers = "$snmp_juniper_ive.9.0";
my $snmp_juniper_iveCpuUtil = "$snmp_juniper_ive.10.0";
my $snmp_juniper_iveMemoryUtil = "$snmp_juniper_ive.11.0";
my $snmp_juniper_iveConcurrentUsers = "$snmp_juniper_ive.12.0";
my $snmp_juniper_MeetingCount = "$snmp_juniper_ive.22.0";
my $snmp_juniper_iveSwapUtil = "$snmp_juniper_ive.24.0";
my $snmp_juniper_fanDescription = "$snmp_juniper_ive.32.0";
my $snmp_juniper_psDescription = "$snmp_juniper_ive.33.0";
my $snmp_juniper_raidDescription = "$snmp_juniper_ive.34.0";

my $snmp_juniper_ucdavis = '.1.3.6.1.4.1.2021';
# Memory
my $snmp_juniper_Memory = "$snmp_juniper_ucdavis.4";
my $snmp_juniper_Memory_TotalSwap = "$snmp_juniper_Memory.3.0";
my $snmp_juniper_Memory_AvailSwap = "$snmp_juniper_Memory.4.0";
my $snmp_juniper_Memory_TotalMem = "$snmp_juniper_Memory.5.0";
my $snmp_juniper_Memory_AvailMem = "$snmp_juniper_Memory.6.0";
my $snmp_juniper_Memory_TotalFree = "$snmp_juniper_Memory.11.0";
my $snmp_juniper_Memory_Shared = "$snmp_juniper_Memory.13.0";
my $snmp_juniper_Memory_Buffer = "$snmp_juniper_Memory.14.0";
my $snmp_juniper_Memory_Cached = "$snmp_juniper_Memory.15.0";
# Disk
my $snmp_juniper_Disk = "$snmp_juniper_ucdavis.9.1";
my $snmp_juniper_Disk_Index = "$snmp_juniper_Disk.1";
my $snmp_juniper_Disk_Total = "$snmp_juniper_Disk.6.1";
my $snmp_juniper_Disk_Avail = "$snmp_juniper_Disk.7.1";
my $snmp_juniper_Disk_Used = "$snmp_juniper_Disk.8.1";
my $snmp_juniper_Disk_Used_Percent = "$snmp_juniper_Disk.9.1";
# Load
my $snmp_juniper_Load = "$snmp_juniper_ucdavis.10.1";
my $snmp_juniper_Load_Index = "$snmp_juniper_Load.1";
my $snmp_juniper_Load_Load = "$snmp_juniper_Load.3";
my $snmp_juniper_Load_Load_1 = "$snmp_juniper_Load_Load.1";
my $snmp_juniper_Load_Load_5 = "$snmp_juniper_Load_Load.2";
my $snmp_juniper_Load_Load_15 = "$snmp_juniper_Load_Load.3";



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
	 -H = Ip/Dns Name of the Juniper           -w = Warning Value
	 -C = SNMP Community                       -c = Critical Value
	 -T = Check type
	 
	 ## Check Types
	 LOG        - Log File Size
	 USERS      - Signed Users
	 MEETINGS   - Active Meetings
	 CPULOAD    - CPU Load
	 MEM        - Memory Usage
	 SWAP       - Swap Usage
	 DISK       - Disk Usage Percentage
	 
	 # Not Implemented
	 FAN        - Fan Fail
	 PS         - Power Supply Fail
	 RAID       - Raid Status
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

### LOG ###
if("$opt{'check_type'}" eq "LOG") {
	my $check = _get_oid_value($snmp_session,$snmp_juniper_logFullPercent);
	($msg,$stat) = _clac_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'},'%');
	$perf = "logsize=$check\%";
### Users ###
} elsif("$opt{'check_type'}" eq "USERS") {
	my $check = _get_oid_value($snmp_session,$snmp_juniper_iveConcurrentUsers);
	my $u_web = _get_oid_value($snmp_session,$snmp_juniper_WebUsers);
	my $u_mail = _get_oid_value($snmp_session,$snmp_juniper_MailUsers);
	my $u_meet = _get_oid_value($snmp_session,$snmp_juniper_MeetingUsers);
	
	unless($u_web) { $u_web = 0; }
	unless($u_mail) { $u_mail = 0; }
	unless($u_meet) { $u_meet = 0; }
	
	($msg,$stat) = _clac_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "all_users=$check web_users=$u_web mail_users=$u_mail meeting_users=$u_meet";
### MEETINGS ###
} elsif("$opt{'check_type'}" eq "MEETINGS") {
	my $check = _get_oid_value($snmp_session,$snmp_juniper_MeetingCount);
	unless($check) { $check = 0; }
	($msg,$stat) = _clac_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "meetings=$check";
### CPULOAD ###
} elsif("$opt{'check_type'}" eq "CPULOAD") {
	my $load1 = _get_oid_value($snmp_session,$snmp_juniper_Load_Load_1);
	my $load5 = _get_oid_value($snmp_session,$snmp_juniper_Load_Load_5);
	my $load15 = _get_oid_value($snmp_session,$snmp_juniper_Load_Load_15);
	
	($msg,$stat) = _clac_err_stat($load1,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "load1min=$load1 load5min=$load5 load15min=$load15";
### MEM ###
} elsif("$opt{'check_type'}" eq "MEM") {
	my $r_mem_tbl = $snmp_session->get_table($snmp_juniper_Memory);
	my $Used_Mem = $$r_mem_tbl{$snmp_juniper_Memory_TotalMem} - $$r_mem_tbl{$snmp_juniper_Memory_AvailMem};
	my $Used_Percent = int(($Used_Mem / $$r_mem_tbl{$snmp_juniper_Memory_TotalMem}) * 100);
	($msg,$stat) = _clac_err_stat($Used_Percent,$opt{'check_type'},$opt{'warn'},$opt{'crit'},'%');
	$perf = "total=$$r_mem_tbl{$snmp_juniper_Memory_TotalMem}\k used=$Used_Mem shared=$$r_mem_tbl{$snmp_juniper_Memory_Shared}\k buffer=$$r_mem_tbl{$snmp_juniper_Memory_Buffer}\k cached=$$r_mem_tbl{$snmp_juniper_Memory_Cached}\k";
### SWAP ###
} elsif("$opt{'check_type'}" eq "SWAP") {
	my $r_mem_tbl = $snmp_session->get_table($snmp_juniper_Memory);
	my $Used_Mem = $$r_mem_tbl{$snmp_juniper_Memory_TotalSwap} - $$r_mem_tbl{$snmp_juniper_Memory_AvailSwap};
	my $Used_Percent = int(($Used_Mem / $$r_mem_tbl{$snmp_juniper_Memory_TotalSwap}) * 100);
	($msg,$stat) = _clac_err_stat($Used_Percent,$opt{'check_type'},$opt{'warn'},$opt{'crit'},'%');
	$perf = "total=$$r_mem_tbl{$snmp_juniper_Memory_TotalSwap}\k used=$Used_Mem\k";
### DISK ###
} elsif("$opt{'check_type'}" eq "DISK") {
	my $r_disk_tbl = $snmp_session->get_table($snmp_juniper_Disk);
	($msg,$stat) = _clac_err_stat($$r_disk_tbl{$snmp_juniper_Disk_Used_Percent},$opt{'check_type'},$opt{'warn'},$opt{'crit'},'%');
	$perf = "total=$$r_disk_tbl{$snmp_juniper_Disk_Total} used=$$r_disk_tbl{$snmp_juniper_Disk_Used}";
### Syntax Error ###
} else {
	FSyntaxError("$opt{'check_type'} invalid parameter !");
}


print "$msg | $perf\n";
exit($stat);

