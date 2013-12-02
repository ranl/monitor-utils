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
use Time::Local;

# Used only for performance via pnp4Nagios

sub FSyntaxError {
	print "Syntax Error !\n";
	print "$0 cjs \n";
	print "\tcjs = Cell Job Summary\n";
	print "$0 qjs \"queue name\"\n";
	print "\tqjs = Queue Job Summary\n";
	exit(3);
}

if($#ARGV < 0) {
        FSyntaxError;
}

my $sge_settings = "/path/to/sge/settings.sh";
my $perf_data;
my $msg;
my $queue;

sub cjs {
	my @qstat_grid_jobs = split("\n",`source $sge_settings ; qstat | sed '1,2d' | awk '{print \$5}' | sort`);
	my %sum_grid_jobs;
	$sum_grid_jobs{'r'} = 0;
	$sum_grid_jobs{'Eqw'} = 0;
	$sum_grid_jobs{'qw'} = 0;
	$sum_grid_jobs{'t'} = 0;
	$sum_grid_jobs{'other'} = 0;
	my $grid_job_sum = 0;
	$msg = "Cell Job Summary";
	
	foreach my $state (@qstat_grid_jobs) {
		chomp($state);
		$grid_job_sum++;
		if($state eq "r") {
			$sum_grid_jobs{'r'}++;
		} elsif($state eq "Eqw") {
			$sum_grid_jobs{'Eqw'}++;
		} elsif($state eq "qw") {
			$sum_grid_jobs{'qw'}++;
		} elsif($state eq "t") {
			$sum_grid_jobs{'t'}++;
		} else {
			$sum_grid_jobs{'other'}++;
		}
	}
	
	$perf_data = "Sum=$grid_job_sum;0;0 r=$sum_grid_jobs{'r'};0;0 qw=$sum_grid_jobs{'qw'};0;0 Eqw=$sum_grid_jobs{'Eqw'};0;0 t=$sum_grid_jobs{'t'};0;0 others=$sum_grid_jobs{'other'};0;0";
}

sub qjs {
	my @months = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
	my @qstat_queue_info = split(" ",`source $sge_settings ; qstat -g c | sed '1,2d' | grep ^$queue\\ `);
	my @jobs_id = split("\n",`source $sge_settings ; qstat | sed '1,2d' | grep $queue\@ | awk '{print \$1" "\$6" "\$7}'`);
	my %diff;
	$diff{'count'} = 0;
	$diff{'sum'} = 0;
	$msg = "$queue monitor";
	
	foreach my $jobsid (@jobs_id) {
		$diff{'count'}++;
		chomp($jobsid);
		my @jobsid_arr = split(" ",$jobsid);
		my @submit_time_raw = split(" ",`source $sge_settings ; qstat -j $jobsid_arr[0] | grep ^submission_time: | awk '{print \$3" "\$4" "\$5" "\$6}'`);
		my $mon_submit;
		my $x = 1;
		foreach my $month (@months) {
			if($month eq $submit_time_raw[0]) {
				$mon_submit = "$x";
			}
			$x = $x + 1;
		}
		
		my @submit_time_raw2 = split(":",$submit_time_raw[2]);
		my @exec_time_raw2 = split(":",$jobsid_arr[2]);
		my @exec_date_raw2 = split("/",$jobsid_arr[1]);
		
		###time=timelocal($sec, $min, $hours, $day, $mon, $year)
		my $submit_time=timelocal($submit_time_raw2[2], $submit_time_raw2[1], $submit_time_raw2[0], $submit_time_raw[1], $mon_submit, $submit_time_raw[3]);
		my $exec_time=timelocal($exec_time_raw2[2], $exec_time_raw2[1], $exec_time_raw2[0], $exec_date_raw2[1], $exec_date_raw2[0], $exec_date_raw2[2]);
		my $diff = $exec_time - $submit_time;
		$diff{'sum'} = $diff{'sum'} + $diff;
	}
	my $job_avg;
	if($diff{'sum'} == 0) {
		$job_avg = 0;
	} else {
		$job_avg = $diff{'sum'} / $diff{'count'};
	}
	my $avail = $qstat_queue_info[2] + $qstat_queue_info[4];
	$perf_data = "$perf_data $qstat_queue_info[0]_used=$qstat_queue_info[2];0;0 $qstat_queue_info[0]_total=$avail;0;0 job_waiting_avg=$job_avg\sec;0;0";
}




if("$ARGV[0]" eq "cjs") {
	cjs();
} elsif("$ARGV[0]" eq "qjs") {
	if($#ARGV < 1) {
		FSyntaxError;
	}
	$queue = "$ARGV[1]";
	my $is_queue_exists = `source $sge_settings ; qstat -g c | sed '1,2d' | grep -q ^$queue\\  ; echo \$?`;
	chomp($is_queue_exists);
	if("0" ne "$is_queue_exists") {
		FSyntaxError;
	}
	qjs();
	
} else {
	FSyntaxError;
}

print "$msg | $perf_data \n";
exit(0);
