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

my @information = `snmpwalk -c $community -v $version $hostname PowerNet-MIB::rPDU2SensorTempHumidityStatusEntry`;

my ($temperature, $humidity, $temp_status, $humidity_status) = (-1, -1, -1, -1);
foreach(@information) {
  if(/rPDU2SensorTempHumidityStatusTempC\.1.*INTEGER: (\d+)/) {
    $temperature = $1 / 10;
  } elsif(/rPDU2SensorTempHumidityStatusRelativeHumidity\.1.*INTEGER: (\d+)/) {
    $humidity = $1;
  } elsif(/rPDU2SensorTempHumidityStatusTempStatus\.1.*INTEGER: (\w+)/) {
    $temp_status = $1;
  } elsif(/rPDU2SensorTempHumidityStatusHumidityStatus\.1.*INTEGER: (\w+)/) {
    $humidity_status = $1;
  }
}

my @status_message = ();
my @perfdata = ();
if($temperature > -1) {
  push(@perfdata, "temperature=$temperature");
  if(!($temp_status eq "normal")) {
    $state = 2;
    push(@status_message, "Problem with temperature ($temperature°C)");
  } else {
    push(@status_message, "temperature = $temperature°C");
  }
}

if($humidity > -1) {
  push(@perfdata, "humidity=$humidity%");
  if(!($humidity_status eq "normal")) {
    $state = 2;
    push(@status_message, "Problem with humidity ($humidity%)");
  } else {
    push(@status_message, "humidity = $humidity%");
  }
}
print "Temperature/Humidity sensor status is ".$message{$state}." - ".
      join(", ", @status_message)."|".
      join(" ", @perfdata)."\n";

exit($state);