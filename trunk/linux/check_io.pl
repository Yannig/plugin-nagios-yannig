#!/usr/bin/perl
#   heavily inspired me (Yannig Perre <yannig.perre@gmail.com>)
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

my $show_help    = 0;
my $show_version = 0;
my $verbose      = 0;
my $warning      = 0;
my $critical     = 0;
my $interval     = 5;

my $parse_status = GetOptions(
  'h|help'       => \$show_help,
  'v|version'    => \$show_version,
  'd|debug'      => \$verbose,
  'w|warning=s'  => \$warning,
  'c|critical=s' => \$critical,
  'interval=s'   => \$interval,
);

# Field 1   -- # of reads issued
# Field 2   -- # of reads merged
# Field 3   -- # of sectors read
# Field 4   -- # of milliseconds spent reading
# Field 5   -- # of writes completed
# Field 6   -- # of writes merged
# Field 7   -- # of sectors written
# Field 8   -- # of milliseconds spent writing
# Field 9   -- # of I/Os currently in progress
# Field 10 -- # of milliseconds spent doing I/Os
# Field 11 -- weighted # of milliseconds spent doing I/Os

sub get_disk_stat {
  my %perf = ();
  open(DISK, "/proc/diskstats");
  while(<DISK>) {
    next if(!/sd[a-z]+ /);
    my @line = split(/\s+/);
    for(my $i = 0; $i < 3; $i++) { shift(@line); }
    $perf{$line[0]} = \@line;
  }
  close(DISK);
  return %perf;
}

my %disk_stat_1 = get_disk_stat();
sleep($interval);
my %disk_stat_2 = get_disk_stat();

my @perfdata = ();
foreach my $dev(sort(keys(%disk_stat_1))) {
  my @perf_1 = @{$disk_stat_1{$dev}};
  my @perf_2 = @{$disk_stat_2{$dev}};
  my @perf = ();
  for(my $i = 1; $i < scalar(@perf_1); $i++) {
    $perf[$i] = ($perf_2[$i] - $perf_1[$i]) / $interval;
  }
  push(@perfdata, "$dev-io-time=".$perf[10]."ms");
  push(@perfdata, "$dev-read-kps=".($perf[3] / 2)."kps");
  push(@perfdata, "$dev-read-time=".$perf[4]."ms");
  push(@perfdata, "$dev-write-kps=".($perf[7] / 2)."kps");
  push(@perfdata, "$dev-write-time=".$perf[8]."ms");
}

print "IO information|";
print join(" ", sort(@perfdata));
print "\n";