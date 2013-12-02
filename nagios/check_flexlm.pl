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
# This script is mainly for performance graph using pnp the usage of the license

use strict;

sub FSyntaxError {
	print "Syntax Error !\n";
	print "$0 [absolute path to lmutil] [absolute path to license file] [feature full name (from lmstat)]\n";
	exit(1);
}

if($#ARGV != 3) {
        FSyntaxError;
}

# General Settings
my $lmutil = "$ARGV[0]"; chomp($lmutil);
my $lm_file = "$ARGV[1]"; chomp($lm_file);
my $feature = "$ARGV[2]"; chomp($feature);
my $daemon = "$ARGV[3]";
my $vendor = `basename $lm_file | sed 's/.lic//g'`; chomp($vendor);

my @lmstat_out = split(";",`$lmutil lmstat -c $lm_file -S $daemon | grep ^Users\\ of\\ $feature: | sed -e 's/:/;/g' -e 's/  (Total of //g' -e 's/  Total of //g' -e 's/ licenses issued//g' -e 's/ licenses in use)\$//g' -e 's/ license issued//g' -e 's/ license in use)\$//g' -e 's/^Users of //g'`);
if($#lmstat_out < 1) {
	print "$vendor $daemon Is Down\n";
	exit(2);
}

print "$vendor $daemon $feature | total=$lmstat_out[1] used=$lmstat_out[2]\n";
exit(0);
