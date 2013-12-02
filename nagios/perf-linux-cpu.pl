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

# Info
# 
# Used only for performance monitoring via check_by_ssh

my $msg = "MPSTAT Performance |";
my $x = 0;
my %header;
my $fcount = -1;
my $mpstat = `which mpstat`; chomp($mpstat);
my @out = split("\n",`$mpstat |tail -n 2`);
foreach my $line (@out) {
	my @chopped = split(" ",$line);
	shift(@chopped);shift(@chopped);shift(@chopped);
	
	my $count = 0;
	if($x == 0) {
		foreach my $field (@chopped) {
			if($field =~ /^%/) {
				$field =~ s/^%//; chomp($field);
				$fcount++;
				$header{"$fcount"} = $field;
				$count++;
			}
		}
	} else {
		for(my $i=0;$i<=$fcount;$i++) {
			my $tmp = int($chopped[$i]); chomp($tmp);
			$msg = "$msg $header{$i}=$tmp;0;0;0";
		}
	}
	$x++;
}

print "$msg\n";
exit(0);