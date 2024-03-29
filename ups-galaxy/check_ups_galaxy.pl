#!/usr/bin/perl
use Getopt::Long;
Getopt::Long::Configure('bundling');

use strict;

my $hostname = 0;
my $community = "public";
my $port      = 161;
my $version   = "2c";
my $show_help = 0;
my $verbose   = 0;
my $state     = 0;
my %message   = (0, "OK", 1, "Warning", 2, "CRITICAL", 3, "Unknown");

GetOptions(
  "h|help"        => \$show_help,
  "v|snmp=s"      => \$version,
  "C|community=s" => \$community,
  "p|port=s"      => \$port,
  "H|hostname=s"  => \$hostname,
  "verbose"       => \$verbose,
);

sub usage {
  print "$0 -H <HOSTNAME> [-C <COMUNITY>] [-v|--snmp <SNMP_VERSION>] [-p <PORT>] [--verbose]\n";
}

if(!$hostname || $show_help) { usage(); exit(); }

my @information = `snmpwalk -c $community -v $version $hostname MG-SNMP-UPS-MIB::upsmgBattery`;

my @message = ();
my @perfdata = ();
foreach(@information) {
  if(/upsmgBattery(RemainingTime|Level|Voltage|Current|Temperature).*INTEGER: (\d+)/) {
    push(@perfdata, "$1=$2");
  } elsif(/upsmgBattery(FaultBattery|Replacement|LowBattery|ChargerFault|LowCondition).*INTEGER: (\w+)/) {
    if(!($2 eq "no")) {
      push(@message, "Error with $1 (status = $2");
      $state = 2;
    } else {
      push(@message, "$1=$2");
    }
  }
}

if(scalar(@perfdata) == 0 || scalar(@message) == 0) {
  print "Unable to retrieve information from $hostname ...\n";
  exit(3);
}

print "Galaxy battery status is ".$message{$state}." (".
      join(", ", sort(@message)).")|".
      join(" ", sort(@perfdata))."\n";
exit($state);
