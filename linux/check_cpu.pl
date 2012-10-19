#!/usr/bin/perl
#   heavily inspired from:
#   check_cpu.sh (author: Mike Adolphs http://www.matejunkie.com/)
#   heavily modified (port to perl and customization) by
#   Yannig Perre <yannig.perre@gmail.com>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

use strict;
use Getopt::Long;

my $progname = $0;
my $version  = "Version 1.0,";
my $author = "2012, Yannig Perré (http://lesaventuresdeyannigdanslemondeit.blogspot.fr/)";
my %message = (0, "OK", 1, "Warning", 2, "CRITICAL", 3, "Unknown");
my $verbose = 0;

my $interval = 1;

sub print_version {
  print "$version $author";
}

sub print_help {
  print_version();
  print "
$progname is a Nagios plugin to monitor CPU utilization. It makes
use of /proc/stat and calculates it through Jiffies rather than
using another frontend tool like iostat or top.
When using optional warning/critical thresholds all values except
idle are aggregated and compared to the thresholds. There's
currently no support for warning/critical thresholds for specific
usage parameters.

$progname [-i/--interval] [-w/--warning] [-c/--critical]

Options:
  --interval|-i)
    Defines the pause between the two times /proc/stat is being
    parsed. Higher values could lead to more accurate result.
    Default is: 1 second
  --warning|-w)
    Sets a warning level for CPU user. Default is: off
  --critical|-c)
    Sets a critical level for CPU user. Default is: off\n";
  exit(0);
}

my $show_help    = 0;
my $show_version = 0;
my $verbose      = 0;
my $warning      = 0;
my $critical     = 0;

my $parse_status = GetOptions(
  'h|help'       => \$show_help,
  'v|version'    => \$show_version,
  'd|debug'      => \$verbose,
  'i|interval=s' => \$interval,
  'w|warning=s'  => \$warning,
  'c|critical=s' => \$critical,
  'd|debug'      => \$verbose,
);

if(!$parse_status) {
  print "Unknown argument: $1";
  print_help();
  exit(3);
}

sub return_cpu_vals {
  open(CPU, "/proc/stat");
  my @tmp = <CPU>;
  my @tmp = grep(/^cpu\s/, @tmp);
  my @cpu_stats = split(/\s+/, $tmp[0]);
  print @tmp if($verbose);
  close(CPU);
  return @cpu_stats;
}

my @cpu_stats_1 = return_cpu_vals();
my $tmp1_cpu_total = $cpu_stats_1[1] + $cpu_stats_1[2] + $cpu_stats_1[3] + $cpu_stats_1[4] +
                     $cpu_stats_1[5] + $cpu_stats_1[6] + $cpu_stats_1[7] + $cpu_stats_1[8];

sleep($interval);

my @cpu_stats_2 = return_cpu_vals();
my $tmp2_cpu_total = $cpu_stats_2[1] + $cpu_stats_2[2] + $cpu_stats_2[3] + $cpu_stats_2[4] +
                     $cpu_stats_2[5] + $cpu_stats_2[6] + $cpu_stats_2[7] + $cpu_stats_2[8];

my $diff_cpu_user    = $cpu_stats_2[1] - $cpu_stats_1[1];
my $diff_cpu_nice    = $cpu_stats_2[2] - $cpu_stats_1[2];
my $diff_cpu_sys     = $cpu_stats_2[3] - $cpu_stats_1[3];
my $diff_cpu_idle    = $cpu_stats_2[4] - $cpu_stats_1[4];
my $diff_cpu_iowait  = $cpu_stats_2[5] - $cpu_stats_1[5];
my $diff_cpu_irq     = $cpu_stats_2[6] - $cpu_stats_1[6];
my $diff_cpu_softirq = $cpu_stats_2[7] - $cpu_stats_1[7];
my $diff_cpu_total   = $tmp2_cpu_total - $tmp1_cpu_total;

my $cpu_user    = (100 * $diff_cpu_user    / $diff_cpu_total);
my $cpu_nice    = (100 * $diff_cpu_nice    / $diff_cpu_total);
my $cpu_sys     = (100 * $diff_cpu_sys     / $diff_cpu_total);
my $cpu_idle    = (100 * $diff_cpu_idle    / $diff_cpu_total);
my $cpu_iowait  = (100 * $diff_cpu_iowait  / $diff_cpu_total);
my $cpu_irq     = (100 * $diff_cpu_irq     / $diff_cpu_total);
my $cpu_softirq = (100 * $diff_cpu_softirq / $diff_cpu_total);
my $cpu_total   = (100 * $diff_cpu_total   / $diff_cpu_total);
my $cpu_usage   = $cpu_user + $cpu_nice + $cpu_sys + $cpu_iowait +$cpu_irq + $cpu_softirq;

my $output = sprintf("user: %.2f, nice: %.2f, sys: %.2f, iowait: %.2f, irq: %.2f, softirq: %.2f, idle: %.2f",
                     $cpu_user, $cpu_nice, $cpu_sys, $cpu_iowait, $cpu_irq, $cpu_softirq, $cpu_idle);

my $perfdata = sprintf("user=%.2f%% nice=%.2f%% sys=%.2f%% softirq=%.2f%% iowait=%.2f%% irq=%.2f%% idle=%.2f%%",
                       $cpu_user, $cpu_nice, $cpu_sys, $cpu_softirq, $cpu_iowait, $cpu_irq, $cpu_idle);

if($warning && $critical && $warning > $critical) {
  print "Please adjust your warning/critical thresholds. The warning must be lower than the critical level!\n";
  exit(3);
}
my $state = 0;

if($critical && $cpu_usage > $critical) {
  $state = 2;
} elsif($warning && $cpu_usage > $warning) {
  $state = 1;
}

print $message{$state}." - $output|$perfdata\n";
exit($state);