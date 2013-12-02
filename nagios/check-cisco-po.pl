#!/usr/bin/env perl

# Modules
use strict;
use Net::SNMP;
use Getopt::Long;
Getopt::Long::Configure('bundling');

# Interfaces
my $S_int_entry = ".1.3.6.1.2.1.2.2.1";
my $S_int_desc = "$S_int_entry.2";
my $S_int_operstatus = "$S_int_entry.8";
my $S_int_speed = '.1.3.6.1.2.1.31.1.1.1.15';

# Status of operstatus
my %int_status_index = (
	1 => 'up',
	2 => 'down',
	3 => 'testing',
	4 => 'unknown',
	5 => 'notPresent',
	6 => 'lowerLayerDown',
);

# Nagios Exit codes
my $OK = 0;
my $WARNING = 1;
my $CRITICAL = 2;
my $UNKNOWN = 3;

# Output & exit code
my $stat = $OK;
my $msg;
my $perf;

### Functions
###############
sub _create_session
{
	my ($server, $comm) = @_;
	my $version = 1;
	my ($sess, $err) = Net::SNMP->session( -hostname => $server, -version => $version, -community => $comm);
	if (!defined($sess)) {
		print "Can't create SNMP session to $server\n";
		exit(1);
	}
	return $sess;
}

sub _get_oid_value(@)
{
	my $sess = shift;
	my $local_oid = shift;
	my $r_return = $sess->get_request(-varbindlist => [$local_oid]);
	return($r_return->{$local_oid});
}

sub _syntax_err(@)
{
	my $msg = shift;
	print <<EOU;
 Err: $msg
 
 Syntax:
 -H [Ip/Dns Name of the Switch] -C [snmp community] -P [port-channel number] -s [speed of each interface in the po(Mbps)] -n [number of ints in the po]
	
EOU
	exit(3);
}


# User Input
my %opt;
my $result = GetOptions(\%opt,
			'switch|H=s',
			'community|C=s',
			'interface|P=i',
			'speed|s=i',
			'numIfInts|n=i',
);

# Validate user input
_syntax_err("Missing -H") unless defined $opt{'switch'};
_syntax_err("Missing -C") unless defined $opt{'community'};
_syntax_err("Missing -P") unless defined $opt{'interface'};
_syntax_err("Missing -s") unless defined $opt{'speed'};
_syntax_err("Missing -n") unless defined $opt{'numIfInts'};

# Connect to switch
our $snmp_session = _create_session($opt{'switch'},$opt{'community'});

# Get port-channel snmp id
my $snmpId;
my $R_tbl = $snmp_session->get_table($S_int_desc);
my $is_int_exists = 0;
foreach my $oid ( keys %$R_tbl) {
	if($$R_tbl{$oid} =~ "[Pp]ort-channel$opt{'interface'}\$")
	{
		$snmpId = "$oid";
		$snmpId =~ s/$S_int_desc\.//;
	}
}

# Exit if non-were found
_syntax_err("Can't find Port-channel$opt{'interface'}") if($snmpId eq "");

# Check operstatus
my $operationStatus = _get_oid_value($snmp_session,"$S_int_operstatus.$snmpId");

# Quit if po is down totally
if($operationStatus ne 1)
{
	$stat = $CRITICAL;
	$msg = "CRIT: Port-channel$opt{'interface'} is $int_status_index{$operationStatus}";
	$perf = "upInts=0";
}

# Check speed of the po and cross reference with $opt{'numIfInts'}*$opt{'speed'};
if($stat == $OK)
{
	my $speed = _get_oid_value($snmp_session,"$S_int_speed.$snmpId");
	my $expectedSpeed = $opt{'numIfInts'} * $opt{'speed'};
	if($speed == $expectedSpeed) # Everthing is ok
	{
		$stat = $OK;
		$msg = "OK: Port-channel$opt{'interface'} is $int_status_index{$operationStatus}";
		$perf = "upInts=$opt{'numIfInts'}";
	}
	else # at least one or more interfaces are down, calculate how many
	{
		my $upInts = $opt{'numIfInts'} - int($speed / $opt{'speed'});
		$stat = $WARNING;
		$msg = "WARNING: $upInts/$opt{'numIfInts'} in Port-channel$opt{'interface'} are down";
		$perf = "upInts=$upInts";
	}
}

# Exit
print "$msg | $perf\n";
exit($stat);

