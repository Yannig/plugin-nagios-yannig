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
use File::Basename;
use Getopt::Long;

my $show_help    = 0;
my $verbose      = 0;
my $netstat      = "/bin/netstat";

sub usage {
  my $program_name = "check_net_io";
  print "Usage :
  \$ $program_name [OPTIONS]

Check Linux network io
  -h  --help                          Display this help and exit.
  -v  --verbose                       Verbose.

";
}

GetOptions(
  "h"              => \$show_help,
  "help"           => \$show_help,
  "v"              => \$verbose,
  "verbose"        => \$verbose,
);
if($show_help) { usage(); exit(0); }

if(!-x($netstat)) {
  print "Warning: cannot execute netstat command ($netstat)\n";
  exit(1);
}
$ENV{"LC_ALL"} = "C";
open(CMD, "$netstat -ien |");

print "Net IO Linux|";
my %perfdata = ();
my $found_eth = 0;
my($name, $mtu, $ipkts, $ierrs, $opkts, $oerrs, $coll);
while(<CMD>) {
  if(/(^eth\d+)\s+/) {
    ($name, $ipkts, $ierrs, $opkts, $oerrs, $coll) = ($1, 0, 0, 0, 0, 5);
    $found_eth = 1;
  } elsif(/RX packets:\d+ errors:(\d+)/) {
    $ierrs = $1;
  } elsif(/TX packets:\d+ errors:(\d+)/) {
    $oerrs = $1;
  } elsif(/\s+collisions:(\d+)/) {
    $coll = $1;
  } elsif(/RX bytes:(\d+).*TX bytes:(\d+)/) {
    $ipkts = int($1 / 1024 + 0.5); $opkts = int($2 / 1024 + 0.5);
    next if(!$found_eth);
    $perfdata{$name} = "$name-input-kbs=${ipkts}c $name-output-kbs=${opkts}c ".
                       "$name-input-error=${ierrs}c $name-output-error=${oerrs}c ".
                       "$name-collision=${coll}c";
    $found_eth = 0;
  }
}

my @perfdata = ();
foreach(sort(keys(%perfdata))) {
  push(@perfdata, $perfdata{$_});
}
print join(" ", sort(@perfdata))."\n";
