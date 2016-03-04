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
## Original version written by 
## ran.leibman@gmail.com
## Additionial checks code written
## by laurent.dufour@havas.com
##
## the following parameters has
## been tested against a PA5050 and PA3020
##
## cpu|firmware|ha|model|
## sessions|udp_sessions|tcp_sessions
## |icmp_sessions
##
#####################################
#####################################


use strict;
use lib "/usr/lib/nagios/plugins/";
use Net::SNMP;
my $stat;
my $msg;
my $perf;
my $script_name = "check-paloalto-A500.pl";
my $script_version = 1.1;


### SNMP OIDs
###############
my $s_cpu_mgmt = '.1.3.6.1.2.1.25.3.3.1.2.1';
my $s_cpu_data = '.1.3.6.1.2.1.25.3.3.1.2.2';
my $s_firmware = '.1.3.6.1.2.1.25.3.3.1.2.2';
my $s_firmware_version = '.1.3.6.1.4.1.25461.2.1.2.1.1.0';
my $s_ha_mode = '.1.3.6.1.4.1.25461.2.1.2.1.13.0';
my $s_ha_local_state = '.1.3.6.1.4.1.25461.2.1.2.1.11.0';
my $s_ha_peer_state = '.1.3.6.1.4.1.25461.2.1.2.1.12.0';
my $s_pa_model = '.1.3.6.1.4.1.25461.2.1.2.2.1.0';
my $s_pa_max_sessions = '.1.3.6.1.4.1.25461.2.1.2.3.2.0';
my $s_pa_total_active_sessions = '.1.3.6.1.4.1.25461.2.1.2.3.3.0';
my $s_pa_total_tcp_active_sessions = '.1.3.6.1.4.1.25461.2.1.2.3.4.0';
my $s_pa_total_udp_active_sessions = '.1.3.6.1.4.1.25461.2.1.2.3.5.0';
my $s_pa_total_icmp_active_sessions = '.1.3.6.1.4.1.25461.2.1.2.3.6.0';

### Functions
###############
sub _create_session {
    my ($server, $comm) = @_;
    my $snmp_version = 2;
    my ($sess, $err) = Net::SNMP->session( -hostname => $server, -version => $snmp_version, -community => $comm);
    if (!defined($sess)) {
	print "Can't create SNMP session to $server\n";
	exit(1);
    }
    return $sess;
}

sub FSyntaxError {
    print "Syntax Error !\n";
# print "$0 -H [ip|dnsname] -C [snmp community] -t [temp|fan|ps|cpu|mem|module|freeint|firmware|ha|model|sessions|udp_sessions|tcp_sessions|icmp_sessions] -w [warning value] -c [critical value] -d [days]\n";
    print "$script_name\n";
    print "Version : $script_version\n";
    print "-H = Ip/Dns Name of the FW\n";
    print "-C = SNMP Community\n";
    print "-t = Check type (currently only cpu/firmware/model/ha/sessions/icmp_sessions/tcp_sessions/udp_sessions)\n";
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


### model ###
if($check_type eq "model") {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_model]);
    my $palo_model = "$R_firm->{$s_pa_model}";


    $msg = "OK: Palo Alto  $palo_model";
    $perf="";
    $stat = 0;
}

### HA MODE ###
elsif($check_type eq "ha") {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_ha_mode]);
    my $ha_mode = "$R_firm->{$s_ha_mode}";

    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_ha_local_state]);
    my $ha_local_state = "$R_firm->{$s_ha_local_state}";

    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_ha_peer_state]);
    my $ha_peer_state = "$R_firm->{$s_ha_peer_state}";


    $msg =  "OK: High Availablity Mode :  $ha_mode - Local :  $ha_local_state - Peer  :  $ha_peer_state\n";
    $perf="";
    $stat = 0;
}


### SESSIONS ###
elsif($check_type eq "sessions") {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_max_sessions]);
    my $pa_max_sessions = "$R_firm->{$s_pa_max_sessions}";

    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_total_active_sessions]);
    my $pa_total_active_sessions = "$R_firm->{$s_pa_total_active_sessions}";

	$perf=" - Max Active Sessions :  $pa_max_sessions";
    
    if($pa_total_active_sessions > $crit ) {
	$msg =  "CRIT: Total Active Sessions :  $pa_total_active_sessions".$perf;
	$stat = 2;
    } elsif($pa_total_active_sessions > $warn ) {
	$msg =  "WARN: Total Active Sessions :  $pa_total_active_sessions".$perf;
	$stat = 1;
    } else {
	$msg =  "OK:   Total Active Sessions :  $pa_total_active_sessions".$perf;
	$stat = 0;

    }

	$perf="";

}

### TCP SESSIONS ###
elsif($check_type eq "tcp_sessions") {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_total_tcp_active_sessions]);
    my $pa_total_tcp_active_sessions = "$R_firm->{$s_pa_total_tcp_active_sessions}";

    
    if($pa_total_tcp_active_sessions > $crit ) {
	$msg =  "CRIT: TCP Active Sessions :  $pa_total_tcp_active_sessions";
	$stat = 2;
    } elsif($pa_total_tcp_active_sessions > $warn ) {
	$msg =  "WARN: TCP Active Sessions :  $pa_total_tcp_active_sessions";
	$stat = 1;
    } else {
	$msg =  "OK:   TCP Active Sessions :  $pa_total_tcp_active_sessions";
	$stat = 0;

    }

	$perf="";

}

### UDP SESSIONS ###
elsif($check_type eq "udp_sessions") {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_total_udp_active_sessions]);
    my $pa_total_udp_active_sessions = "$R_firm->{$s_pa_total_udp_active_sessions}";

    
    if($pa_total_udp_active_sessions > $crit ) {
	$msg =  "CRIT: UDP Active Sessions :  $pa_total_udp_active_sessions";
	$stat = 2;
    } elsif($pa_total_udp_active_sessions > $warn ) {
	$msg =  "WARN: UDP Active Sessions :  $pa_total_udp_active_sessions";
	$stat = 1;
    } else {
	$msg =  "OK:   UDP Active Sessions :  $pa_total_udp_active_sessions";
	$stat = 0;

    }

	$perf="";

}

### ICMP SESSIONS ###
elsif($check_type eq "icmp_sessions") {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_pa_total_icmp_active_sessions]);
    my $pa_total_icmp_active_sessions = "$R_firm->{$s_pa_total_icmp_active_sessions}";

    
    if($pa_total_icmp_active_sessions > $crit ) {
	$msg =  "CRIT: ICMP Active Sessions :  $pa_total_icmp_active_sessions";
	$stat = 2;
    } elsif($pa_total_icmp_active_sessions > $warn ) {
	$msg =  "WARN: ICMP Active Sessions :  $pa_total_icmp_active_sessions";
	$stat = 1;
    } else {
	$msg =  "OK:   ICMP Active Sessions :  $pa_total_icmp_active_sessions";
	$stat = 0;

    }

	$perf="";

}

### firmware ###
elsif($check_type eq "firmware") {
    my $R_firm = $snmp_session->get_request(-varbindlist => [$s_firmware_version]);
    my $palo_os_ver = "$R_firm->{$s_firmware_version}";


    $msg = "OK: Firmware $palo_os_ver";
    $perf="";
    $stat = 0;
}

### CPU ###
elsif($check_type eq "cpu") {
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

if ($perf eq "") { 
 print "$msg\n";
} else {
 print "$msg | $perf\n";
}

exit($stat);
