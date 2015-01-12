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
my $days = 14;
my $script_name = "check-cisco.pl";

### SNMP OIDs
###############
# Temperature
my $S_temp = ".1.3.6.1.4.1.9.9.13.1.3.1.3";
# Memory
my $S_mem_used = ".1.3.6.1.4.1.9.9.48.1.1.1.5.1"; # Byte
my $S_mem_free = ".1.3.6.1.4.1.9.9.48.1.1.1.6.1"; # Byte
# CPU Load
my $S_load_5s = ".1.3.6.1.4.1.9.2.1.56.0";
my $S_load_1m = ".1.3.6.1.4.1.9.2.1.57.0";
my $S_load_5m = ".1.3.6.1.4.1.9.2.1.58.0";
# Power Supply
my $S_ps = ".1.3.6.1.4.1.9.9.13.1.5.1";
my $S_ps_name = "$S_ps.2";
my $S_ps_stat = "$S_ps.3";
# Fan
my $S_fan = ".1.3.6.1.4.1.9.9.13.1.4.1";
my $S_fan_name = "$S_fan.2";
my $S_fan_stat = "$S_fan.3";
# Module
my $S_module_status = ".1.3.6.1.4.1.9.9.117.1.2.1.1.2";
# Interfaces
my $S_int_entry = ".1.3.6.1.2.1.2.2.1";
my $S_int_desc = "$S_int_entry.2";
my $S_int_adminstatus = "$S_int_entry.7";
my $S_int_operstatus = "$S_int_entry.8";
my $S_int_lastchange = "$S_int_entry.9";
my $S_int_InOctets = "$S_int_entry.10";
my $S_int_OutOctets = "$S_int_entry.16";
my $S_int_number = ".1.3.6.1.2.1.2.1.0";

# SNMP Status Codes
my %phy_dev_status = (
	1 => 'normal',
	2 => 'warning',
	3 => 'critical',
	4 => 'shutdown',
	5 => 'notPresent',
	6 => 'notFunctioning',
);
my %module_status_code = (
	1 => 'unknown',
	2 => 'ok',
	3 => 'disabled',
	4 => 'okButDiagFailed',
	5 => 'boot',
	6 => 'selfTest',
	7 => 'failed',
	8 => 'missing',
	9 => 'mismatchWithParent',
	10 => 'mismatchConfig',
	11 => 'diagFailed',
	12 => 'dormant',
	13 => 'outOfServiceAdmin',
	14 => 'outOfServiceEnvTemp',
	15 => 'poweredDown',
	16 => 'poweredUp',
	17 => 'powerDenied',
	18 => 'powerCycled',
	19 => 'okButPowerOverWarning',
	20 => 'okButPowerOverCritical',
	21 => 'syncInProgress',
);
my %int_status_index = (
	1 => 'up',
	2 => 'down',
	3 => 'testing',
	4 => 'unknown',
	5 => 'notPresent',
	6 => 'lowerLayerDown',
);

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
	print "-H = Ip/Dns Name of the Switch\n";
	print "-C = SNMP Community\n";
	print "-t = Check type\n";
	print "\ttemp   	- Temperature\n";
	print "\tfan    	- Fan Fail\n";
	print "\tps     	- Power Supply Fail\n";
	print "\tcpu    	- CPU Load\n";
	print "\tmem    	- Memory\n";
	print "\tmodule		- Module Health\n";
	print "\tfreeint - Free eth interfaces for X days (-d)\n";
	print "\tint - Interface Operation Stat (use with -i or -o)\n";
	print "-w = Warning Value\n";
	print "-c = Critical Value\n";
	print "-d = number of days that the ethernet interface hasn't change state, default is 14 (only for -t freeint)\n";
	print "-i = Interface Name (only for -t int)\n";
	print "-o = Interface OID (only for -t int)\n";
	exit(3);
}

if($#ARGV < 5 or $#ARGV > 11) {
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
my $oidint;

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
	} elsif("$temp" eq '-i') {
		$int = shift(@ARGV);
	} elsif("$temp" eq '-o') {
		$oidint = shift(@ARGV);
	} elsif("$temp" eq '-d') {
		$days = shift(@ARGV);
		if("$days" eq "") {
			$days = 14;
		}
	} else {
		FSyntaxError();
	}
}

# Validate Warning
if("$check_type" ne "temp") {
	if($warn > $crit and "$check_type" ne "freeint" and "$check_type" ne "mem") {
		print "Warning can't be larger then Critical: $warn > $crit\n";
		FSyntaxError();
	} elsif($warn < $crit and "$check_type" eq "freeint") {
		print "Warning can't be smaller then Critical: $warn < $crit in intfree check\n";
		FSyntaxError();
	} elsif($warn < $crit and "$check_type" eq "mem") {
		print "Warning can't be smaller then Critical: $warn < $crit in intfree check\n";
		FSyntaxError();
	}
}

# Establish SNMP Session
our $snmp_session = _create_session($switch,$community);

### Temperature ###
if($check_type =~ /^temp/) {
	my $temp;
	my $R_tbl = $snmp_session->get_table($S_temp);
	foreach my $oid ( keys %$R_tbl) {
		$temp = "$$R_tbl{$oid}";
		last;
	}
	
	if("$temp" eq "") {
		print "The switch $switch can't report temperature via SNMP\n";
		FSyntaxError();
	}
	
	if($temp > 1) {
		if($warn > $crit and "$check_type") {
			print "Warning can't be larger then Critical: $warn > $crit\n";
			FSyntaxError();
		}
		if($temp <= $warn) {
			$stat = 0;
			$msg = "Temperature: OK - Temperature is $temp Celsius";
		}  elsif($temp > $warn and $temp < $crit) {
			$stat = 1;
			$msg = "Temperature: Warn - Temperature is $temp Celsius";
		} elsif($temp >= $crit) {
			$stat = 2;
			$msg = "Temperature: CRIT - Temperature is $temp Celsius";
		}
		$perf = "temperature=$temp;$warn;$crit";
	} else {
		if($warn > 0 or $crit > 0) {
			print "ERR:\nSome switches only show boolean value 0=OK 1=ERROR\nplease dont use -w and -c arguments\n\n";
			FSyntaxError();
		}
		if($temp == 1) {
			$stat = 0;
			$msg = "Temperature: OK";
		} else {
			$stat = 2;
			$msg = "Temperature: CRIT";
		}
		$perf = "temperature=$temp";
	}

### Memory ###

} elsif($check_type eq "mem") {
	my $R_mem_used = $snmp_session->get_request(-varbindlist => [$S_mem_used]);
	my $mem_used = "$R_mem_used->{$S_mem_used}";
	my $R_mem_free = $snmp_session->get_request(-varbindlist => [$S_mem_free]);
	my $mem_free = "$R_mem_free->{$S_mem_free}";
	my $mem_total = $mem_free + $mem_used;
	
	$mem_used = int($mem_used / 1024 / 1024);
	$mem_free = int($mem_free / 1024 / 1024);
	$mem_total = int($mem_total / 1024 / 1024);
	
	my $mem_free_perc = int($mem_free / $mem_total * 100);
	
	if($mem_free_perc > $warn) {
		$stat = 0;
		$msg = "Memory: OK - Free Memory $mem_free_perc%";
	}  elsif($mem_free_perc <= $warn and $mem_free_perc > $crit) {
		$stat = 1;
		$msg = "Memory: Warn - Free Memory $mem_free_perc %";
	} elsif($mem_free_perc <= $crit) {
		$stat = 2;
		$msg = "Memory: CRIT - Free Memory $mem_free_perc %";
	}

	$perf = "memory_total=$mem_total\MB memory_used=$mem_used\MB";

### Interface Stat ###

} elsif($check_type eq "int") {
	my $R_tbl;
	if ($oidint) {
		$R_tbl = $snmp_session->get_request(-varbindlist => ["$oidint"]);
		$int = $$R_tbl{"$oidint"};
	} else {
		$R_tbl = $snmp_session->get_table($S_int_desc);
	}
	my $is_int_exists = 0;
	foreach my $oid ( keys %$R_tbl) {
		my $name = "$$R_tbl{$oid}";
		if($name eq $int) {
			$is_int_exists++;
			my $id = "$oid";
			$id =~ s/$S_int_desc\.//;
			my $R_stat = $snmp_session->get_request(-varbindlist => ["$S_int_operstatus.$id"]);
			my $int_stat = $R_stat->{"$S_int_operstatus.$id"};
			if($int_stat != 1) {
				$stat = 2;
				$msg = "CRIT: $int -> $int_status_index{$int_stat}";
				$perf = "int=0";
			} else {
				$stat = 0;
				$msg = "OK: $int -> $int_status_index{$int_stat}";
				$perf = "int=1";
			}
			last;
		}
		
	}
	
	if($is_int_exists == 0) {
		$stat = 3;
		$msg = "UNKNOWN: $int does not exists";
		$perf = "int=0";
	}

### CPU Load ###

} elsif($check_type eq "cpu") {
	my $R_load_5s = $snmp_session->get_request(-varbindlist => [$S_load_5s]);
	my $load_5s = "$R_load_5s->{$S_load_5s}";
	my $R_load_1m = $snmp_session->get_request(-varbindlist => [$S_load_1m]);
	my $load_1m = "$R_load_1m->{$S_load_1m}";
	my $R_load_5m = $snmp_session->get_request(-varbindlist => [$S_load_5m]);
	my $load_5m = "$R_load_5m->{$S_load_5m}";
	
	if($load_5s <= $warn) {
		$stat = 0;
		$msg = "Cpu: OK - Cpu Load $load_5s% $load_1m% $load_5m%";
	}  elsif($load_5s > $warn and $load_5s < $crit) {
		$stat = 1;
		$msg = "Cpu: Warn - Cpu Load $load_5s% $load_1m% $load_5m%";
	} elsif($load_5s >= $crit) {
		$stat = 2;
		$msg = "Cpu: CRIT - Cpu Load $load_5s% $load_1m% $load_5m%";
	}

	$perf = "cpu_5s=$load_5s\percent;$warn;$crit cpu_1m=$load_1m\percent cpu_5m=$load_5m\percent";

### Fan Status ###

} elsif($check_type eq "fan") {
	my $R_tbl = $snmp_session->get_table($S_fan_name);
	my $total_err = 0;
	my $err_msg;
	my $sum = 0;
	foreach my $oid ( keys %$R_tbl) {
		$sum = $sum + 1;
		my $name = "$$R_tbl{$oid}";
		my $id = "$oid";
		$id =~ s/$S_fan_name\.//;
		my $R_stat = $snmp_session->get_request(-varbindlist => ["$S_fan_stat.$id"]);
		my $stat = $R_stat->{"$S_fan_stat.$id"};
		if($stat != 1) {
			$total_err = $total_err + 1;
			$err_msg = "$err_msg $name -> $phy_dev_status{$stat}";
		}
	}
	
	if($total_err != 0) {
		$err_msg = ", $err_msg have an error";
	} else {
		$err_msg = "all good";
	}
	
	if($total_err <= $warn) {
		$stat = 0;
		$msg = "Fans: OK - $sum Fans are running $err_msg";
	}  elsif($total_err > $warn and $total_err < $crit) {
		$stat = 1;
		$msg = "Fans: Warn - $sum Fans are running $err_msg";
	} elsif($total_err >= $crit) {
		$stat = 2;
		$msg = "Fans: Crit - $sum Fans are running $err_msg";
	}
	
	$perf = "total=$sum err=$total_err";

### Power Supplies ###

} elsif($check_type eq "ps") {
	my $R_tbl = $snmp_session->get_table($S_ps_name);
	my $total_err = 0;
	my $err_msg;
	my $sum = 0;
	foreach my $oid ( keys %$R_tbl) {
		$sum = $sum + 1;
		my $name = "$$R_tbl{$oid}";
		my $id = "$oid";
		$id =~ s/$S_ps_name\.//;
		my $R_stat = $snmp_session->get_request(-varbindlist => ["$S_ps_stat.$id"]);
		my $stat = $R_stat->{"$S_ps_stat.$id"};
		if($stat != 1) {
			$total_err = $total_err + 1;
			$err_msg = "$err_msg $name -> $phy_dev_status{$stat}";
		}
	}
	
	if($total_err != 0) {
		$err_msg = ", $err_msg have an error";
	} else {
		$err_msg = "all good";
	}
	
	if($total_err <= $warn) {
		$stat = 0;
		$msg = "PS: OK - $sum PS are running $err_msg";
	}  elsif($total_err > $warn and $total_err < $crit) {
		$stat = 1;
		$msg = "PS: Warn - $sum PS are running $err_msg";
	} elsif($total_err >= $crit) {
		$stat = 2;
		$msg = "PS: Crit - $sum PS are running $err_msg";
	}
	
	$perf = "total=$sum err=$total_err";

### Module Status ###

} elsif($check_type eq "module") {
	my $R_tbl = $snmp_session->get_table($S_module_status);
	my $total_err = 0;
	my $err_msg;
	my $sum = 0;
	foreach my $oid ( keys %$R_tbl) {
		$sum = $sum + 1;
		my $module_status = "$$R_tbl{$oid}";
		my $id = "$oid";
		$id =~ s/$S_module_status\.//;
		if($module_status != 2) {
			$total_err = $total_err + 1;
			$err_msg = "$err_msg $id -> $module_status_code{$module_status}";
		}
	}
	
	if($sum == 0) {
		print "The switch $switch doesn't have any modules\n";
		FSyntaxError();
	}
	
	if($total_err != 0) {
		$err_msg = ", $err_msg have an error";
	} else {
		$err_msg = "all good";
	}
	
	if($total_err <= $warn) {
		$stat = 0;
		$msg = "Modules: OK - $sum Modules are running $err_msg";
	}  elsif($total_err > $warn and $total_err < $crit) {
		$stat = 1;
		$msg = "Modules: Warn - $sum Modules are running $err_msg";
	} elsif($total_err >= $crit) {
		$stat = 2;
		$msg = "Modules: Crit - $sum Modules are running $err_msg";
	}
	
	$perf = "total=$sum err=$total_err";

### Free Interfaces ###

} elsif($check_type eq "freeint") {
	
	my $R_int_number = $snmp_session->get_request(-varbindlist => [$S_int_number]);
	my $int_number = $R_int_number->{$S_int_number};
	
	my $R_tbl = $snmp_session->get_table($S_int_desc);
	my @ints;
	my $down = 0;
	my $sum = 0;
	
	foreach my $oid ( keys %$R_tbl) {
		if($$R_tbl{$oid} =~ /Ethernet/) {
			$sum++;
			my $id = "$oid";
			$id =~ s/$S_int_desc\.//;
			
			# Admin Status
			my $R_int_adminstatus = $snmp_session->get_request(-varbindlist => ["$S_int_adminstatus.$id"]);
			my $int_adminstatus = $R_int_adminstatus->{"$S_int_adminstatus.$id"};
			# Oper Status
			my $R_int_operstatus = $snmp_session->get_request(-varbindlist => ["$S_int_operstatus.$id"]);
			my $int_operstatus = $R_int_operstatus->{"$S_int_operstatus.$id"};
			# Inbout
			my $R_int_InOctets = $snmp_session->get_request(-varbindlist => ["$S_int_InOctets.$id"]);
			my $int_InOctets = $R_int_InOctets->{"$S_int_InOctets.$id"};
			# Outbound
			my $R_int_OutOctets = $snmp_session->get_request(-varbindlist => ["$S_int_OutOctets.$id"]);
			my $int_OutOctets = $R_int_OutOctets->{"$S_int_OutOctets.$id"};
			# Last Change
			my $R_int_lastchange = $snmp_session->get_request(-varbindlist => ["$S_int_lastchange.$id"]);
			my $int_lastchange = $R_int_lastchange->{"$S_int_lastchange.$id"};
			my @lastchanged = split(" ",$int_lastchange);
			
			if($int_adminstatus == 2 or $int_operstatus == 2) {
				if(("$lastchanged[1]" eq "days," and $lastchanged[1] => $days) or ($int_OutOctets == 0 and $int_InOctets == 0)) {
					$down++;
				}
			}
			
		}
	}
	
	if($down >= $warn) {
		$stat = 0;
		$msg = "Free Interfaces: OK - $down/$sum free interfaces for $days days";
	}  elsif($down < $warn and $down > $crit) {
		$stat = 1;
		$msg = "Free Interfaces: Warn - $down/$sum free interfaces for $days days";
	} elsif($down <= $crit) {
		$stat = 2;
		$msg = "Free Interfaces: CRIT - $down/$sum free interfaces for $days days";
	}
	
	$perf = "total_int=$int_number total_eth=$sum total_eth_free=$down";

### Bad Syntax ###

} else {
	FSyntaxError();
}


print "$msg | $perf\n";
exit($stat);
