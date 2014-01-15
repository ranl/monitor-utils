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
my $script_name = "check-netapp-ng.pl";

### SNMP OIDs
###############
my $snmpFailedFanCount = '.1.3.6.1.4.1.789.1.2.4.2.0';
my $snmpFailPowerSupplyCount = '.1.3.6.1.4.1.789.1.2.4.4.0';
my $snmpcpuBusyTimePerCent = '.1.3.6.1.4.1.789.1.2.1.3.0';
my $snmpenvOverTemperature = '.1.3.6.1.4.1.789.1.2.4.1.0';
my $snmpnvramBatteryStatus = '.1.3.6.1.4.1.789.1.2.5.1.0';
my $snmpFailedDiskCount = '.1.3.6.1.4.1.789.1.6.4.7.0';
my $snmpUpTime = '.1.3.6.1.2.1.1.3.0';
my $snmpCacheAge = '.1.3.6.1.4.1.789.1.2.2.23.0';
my $snmpGlobalStatus = '.1.3.6.1.4.1.789.1.2.2.4.0';
my $snmpGlobalStatus_text = '.1.3.6.1.4.1.789.1.2.2.25.0';
my $snmpNdmpSessions = '.1.3.6.1.4.1.789.1.10.2.0';

my $snmpfilesysvolTable = '.1.3.6.1.4.1.789.1.5.8';
my $snmpfilesysvolTablevolEntryOptions = "$snmpfilesysvolTable.1.7";
my $snmpfilesysvolTablevolEntryvolName = "$snmpfilesysvolTable.1.2";

my $snmp_netapp_volume_id_table_df = ".1.3.6.1.4.1.789.1.5.4.1";
my $snmp_netapp_volume_id_table_df_name = "$snmp_netapp_volume_id_table_df.2";
my $snmp_netapp_volume_id_table_df_total = "$snmp_netapp_volume_id_table_df.3";
my $snmp_netapp_volume_id_table_df_used = "$snmp_netapp_volume_id_table_df.4";
my $snmp_netapp_volume_id_table_df_free = "$snmp_netapp_volume_id_table_df.5";
my $snmp_netapp_volume_id_table_df_used_prec = "$snmp_netapp_volume_id_table_df.6";

my $snmpEnclTable = '.1.3.6.1.4.1.789.1.21.1.2.1';
my $snmpEnclTableIndex = "$snmpEnclTable.1";
my $snmpEnclTableState = "$snmpEnclTable.2";
my $snmpEnclTableShelfAddr = "$snmpEnclTable.3";
my $snmpEnclTablePsFailed = "$snmpEnclTable.15";
my $snmpEnclTableFanFailed = "$snmpEnclTable.18";
my $snmpEnclTableTempOverFail = "$snmpEnclTable.21";
my $snmpEnclTableTempOverWarn = "$snmpEnclTable.22";
my $snmpEnclTableTempUnderFail = "$snmpEnclTable.23";
my $snmpEnclTableTempUnderWarn = "$snmpEnclTable.24";
my $snmpEnclTableElectronicFailed = "$snmpEnclTable.33";
my $snmpEnclTableVoltOverFail = "$snmpEnclTable.36";
my $snmpEnclTableVoltOverWarn = "$snmpEnclTable.37";
my $snmpEnclTableVoltUnderFail = "$snmpEnclTable.38";
my $snmpEnclTableVoltUnderWarn = "$snmpEnclTable.39";


# SNMP Status Codes
my %nvramBatteryStatus = (
	1 => 'ok',
	2 => 'partially discharged',
	3 => 'fully discharged',
	4 => 'not present',
	5 => 'near end of life',
	6 => 'at end of life',
	7 => 'unknown',
);
my %GlobalStatusIndex = (
	1 => 'other',
	2 => 'unknown',
	3 => 'ok',
	4 => 'nonCritical',
	5 => 'critical',
	6 => 'nonRecoverable',
);
my %EcnlStatusIndex = (
	1 => 'initializing',
	2 => 'transitioning',
	3 => 'active',
	4 => 'inactive',
	5 => 'reconfiguring',
	6 => 'nonexistent',
);
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
	 -H = Ip/Dns Name of the Filer             -w = Warning Value
	 -C = SNMP Community                       -c = Critical Value
	 -T = Check type                           --vol = Volume Name
						   -e = vol exclude from snap check
	 TEMP          - Temperature
	 FAN           - Fan Fail
	 PS            - Power Supply Fail
	 CPULOAD       - CPU Load (-w -c)
	 NVRAM         - NVram Battery Status
	 DISKUSED      - Vol Usage Precentage (-w -c --vol)
	 SNAPSHOT      - Snapshot Config (-e volname,volname2,volname3)
	 SHELF         - Shelf Health
	 NDMPSESSIONS  - Number of ndmp sessions (-w -c)
	 GLOBALSTATUS  - Global Status of the filer
	 FAILEDDISK    - Number of failed disks
	 UPTIME        - only show's uptime
	 CACHEAGE      - Cache Age


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
	my $r_msg;
	my $r_stat;
	if($value <= $tmp_warn) {
		$r_stat = $ERRORS{'OK'};
		$r_msg = "OK: $value_type $value%";
	}  elsif($value > $tmp_warn and $value < $tmp_crit) {
		$r_stat = $ERRORS{'WARNING'};
		$r_msg = "WARN: $value_type $value%";
	} elsif($value >= $tmp_crit) {
		$r_stat = $ERRORS{'CRITICAL'};
		$r_msg = "CRIT: $value_type $value%";
	}
	return($r_msg,$r_stat);
}

### Gather input from user
#############################
my %opt;
$opt{'crit'} = 500;
$opt{'warn'} = 500;
my $result = GetOptions(\%opt,
						'filer|H=s',
						'community|C=s',
						'check_type|T=s',
						'warn|w=i',
						'crit|c=i',
						'vol|v=s',
						'exclude|e=s',
						);

FSyntaxError("Missing -H")  unless defined $opt{'filer'};
FSyntaxError("Missing -C")  unless defined $opt{'community'};
FSyntaxError("Missing -T")  unless defined $opt{'check_type'};
if($opt{'vol'}) {
	if($opt{'vol'} !~ /^\/.*\/$/) {
		FSyntaxError("$opt{'vol'} format is /vol/volname/ !");
	}
}
if($opt{'crit'} and $opt{'warn'}) {
	if($opt{'warn'} > $opt{'crit'}) {
		FSyntaxError("Warning can't be larger then Critical: $opt{'warn'} > $opt{'crit'}");
	}
}

# Starting Alaram
alarm($TIMEOUT);

# Establish SNMP Session
our $snmp_session = _create_session($opt{'filer'},$opt{'community'});

### Temperature ###
if("$opt{'check_type'}" eq "TEMP") {
	my $check = _get_oid_value($snmp_session,$snmpenvOverTemperature);
	if($check == 1) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} is ok";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: Over $opt{'check_type'} !";
	}
	$perf = "overtemperature=$check";
### Fan ###
} elsif("$opt{'check_type'}" eq "FAN") {
	my $check = _get_oid_value($snmp_session,$snmpFailedFanCount);
	if($check == 0) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} $check";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} $check !";
	}
	$perf = "failedfans=$check";
### PS ###
} elsif("$opt{'check_type'}" eq "PS") {
	my $check = _get_oid_value($snmp_session,$snmpFailPowerSupplyCount);
	if($check == 0) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} Fail $check";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} Fail $check !";
	}
	$perf = "failedpowersupplies=$check";
### CPULOAD ###
} elsif("$opt{'check_type'}" eq "CPULOAD") {
	my $check = _get_oid_value($snmp_session,$snmpcpuBusyTimePerCent);
	($msg,$stat) = _clac_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "cpuload=$check\percent";
### NVRAM ###
} elsif("$opt{'check_type'}" eq "NVRAM") {
	my $check = _get_oid_value($snmp_session,$snmpnvramBatteryStatus);
	if($check == 1) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} $nvramBatteryStatus{$check}";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} $nvramBatteryStatus{$check}";
	}
	$perf = "nvrambatterystatus=$check";
### DISKUSED ###
} elsif("$opt{'check_type'}" eq "DISKUSED") {
	
	FSyntaxError("Missing -vol")  unless defined $opt{'vol'};
	
	my $r_vol_tbl = $snmp_session->get_table($snmp_netapp_volume_id_table_df_name);
	foreach my $key ( keys %$r_vol_tbl) {
		if("$$r_vol_tbl{$key}" eq "$opt{'vol'}") {
			my @tmp_arr = split(/\./, $key);
			my $oid = pop(@tmp_arr);
			
			my $used = _get_oid_value($snmp_session,"$snmp_netapp_volume_id_table_df_used.$oid");
			my $used_prec = _get_oid_value($snmp_session,"$snmp_netapp_volume_id_table_df_used_prec.$oid");
			
			($msg,$stat) = _clac_err_stat($used_prec,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
			
			$perf = "$$r_vol_tbl{$key}=$used\k";
		}
	}
### SNAPSHOT ###
} elsif("$opt{'check_type'}" eq "SNAPSHOT") {
	my @exc_list = split(',',$opt{'exclude'});
	my @vol_err;
	my $r_vol_tbl = $snmp_session->get_table($snmpfilesysvolTablevolEntryvolName);
	foreach my $key ( keys %$r_vol_tbl) {
		my @tmp_arr = split(/\./, $key);
		my $oid = pop(@tmp_arr);
		my $vol_tmp = "$$r_vol_tbl{$key}";
		
		my $volopt = _get_oid_value($snmp_session,"$snmpfilesysvolTablevolEntryOptions.$oid");
		
		if($volopt !~ /nosnap=off/) {
			my $volcheck = 0;
			foreach my $exvol (@exc_list) {
				if($exvol eq $vol_tmp) {
					$volcheck++;
					last;
				}
			}
			if($volcheck == 0) {
				push(@vol_err,"$vol_tmp");
			}
		}
	}
	
	my $err_count = $#vol_err + 1;
	if($err_count == 0) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} all ok";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} @vol_err not configured";
	}
	$perf = "snapoff=$err_count";
### FAILEDDISK ###
} elsif("$opt{'check_type'}" eq "FAILEDDISK") {
	my $check = _get_oid_value($snmp_session,$snmpFailedDiskCount);
	if($check == 0) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} $check";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} $check";
	}
	$perf = "faileddisks=$check";
	
### UPTIME ###
} elsif("$opt{'check_type'}" eq "UPTIME") {
	my $check = _get_oid_value($snmp_session,$snmpUpTime);
	$msg = "$opt{'check_type'}: $check";
### CACHEAGE ###
} elsif("$opt{'check_type'}" eq "CACHEAGE") {
	my $check = _get_oid_value($snmp_session,$snmpCacheAge);
	($msg,$stat) = _clac_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "cache_age=$check";
### GLOBALSTATUS ###
} elsif("$opt{'check_type'}" eq "GLOBALSTATUS") {
	my $check = _get_oid_value($snmp_session,$snmpGlobalStatus);
	my $global_stat_txt = _get_oid_value($snmp_session,$snmpGlobalStatus_text);
	if($check == 3) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} $GlobalStatusIndex{$check} $check $global_stat_txt";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} $GlobalStatusIndex{$check} $check $global_stat_txt";
	}
	$perf = "globalstatus=$check";
### NDMPSESSIONS ###
} elsif("$opt{'check_type'}" eq "NDMPSESSIONS") {
	my $check = _get_oid_value($snmp_session,$snmpNdmpSessions);
	($msg,$stat) = _clac_err_stat($check,$opt{'check_type'},$opt{'warn'},$opt{'crit'});
	$perf = "ndmpsess=$check";
### SHELF ###
} elsif("$opt{'check_type'}" eq "SHELF") {
	my @errs;
	my $r_shelf = $snmp_session->get_table($snmpEnclTableIndex);
	foreach my $key ( keys %$r_shelf) {
		my @tmp_arr = split(/\./, $key);
		my $oid = pop(@tmp_arr);
		
		my %shelf;
		my @shelf_err;
		my $addr = _get_oid_value($snmp_session,"$snmpEnclTableShelfAddr.$oid");
		
		my $shelf_state = _get_oid_value($snmp_session,"$snmpEnclTableState.$oid");
		
		if($shelf_state != 3) {
			push(@shelf_err,"$addr state $EcnlStatusIndex{$shelf_state},");
		}
		
		$shelf{'PsFail'} = _get_oid_value($snmp_session,"$snmpEnclTablePsFailed.$oid");
		$shelf{'FanFail'} = _get_oid_value($snmp_session,"$snmpEnclTableFanFailed.$oid");
		$shelf{'ElectFail'} = _get_oid_value($snmp_session,"$snmpEnclTableElectronicFailed.$oid");
		$shelf{'TempOverFail'} = _get_oid_value($snmp_session,"$snmpEnclTableTempOverFail.$oid");
		$shelf{'TempOver'} = _get_oid_value($snmp_session,"$snmpEnclTableTempOverWarn.$oid");
		$shelf{'TempUnderFail'} = _get_oid_value($snmp_session,"$snmpEnclTableTempUnderFail.$oid");
		$shelf{'TempUnderWarn'} = _get_oid_value($snmp_session,"$snmpEnclTableTempUnderWarn.$oid");
		$shelf{'VoltOverFail'} = _get_oid_value($snmp_session,"$snmpEnclTableVoltOverFail.$oid");
		$shelf{'VoltOverWarn'} = _get_oid_value($snmp_session,"$snmpEnclTableVoltOverWarn.$oid");
		$shelf{'VoltUnderFail'} = _get_oid_value($snmp_session,"$snmpEnclTableVoltUnderFail.$oid");
		$shelf{'VoltUnderWarn'} = _get_oid_value($snmp_session,"$snmpEnclTableVoltUnderWarn.$oid");
		
		foreach my $subkey ( keys %shelf) {
			if($shelf{$subkey}) { push(@shelf_err,"$addr $subkey,") }
		}
		if($#shelf_err != -1) {
			push(@errs,@shelf_err)
		}
	}

	if($#errs == -1) {
		$stat = $ERRORS{'OK'};
		$msg = "OK: $opt{'check_type'} ok";
		$perf = "shelf=0";
	} else {
		$stat = $ERRORS{'CRITICAL'};
		$msg = "CRIT: $opt{'check_type'} Errors -";
		foreach(@errs) {
			$msg = "$msg $_";
		}
		$perf = "shelf=1";
	}
### Syntax Error ###
} else {
	FSyntaxError("$opt{'check_type'} invalid parameter !");
}


print "$msg | $perf\n";
exit($stat);

