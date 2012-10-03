#!/usr/bin/perl

use strict;

use Net::SNMP;
use Getopt::Long;
Getopt::Long::Configure ("bundling");

my $verbose   = 0;
my $show_help = 0;
my $hostname  = 0;
my $community = 'public';
my $snmp_version = 2;
my $port = 161;
my $module = 0;
my $list = 0;
my $warning = 0;
my $critical = 0;

my %message = (0, "OK", 1, "Warning", 2, "CRITICAL", 3, "Unknown");

my $parse_status = GetOptions(
    'd|debug'           => \$verbose,
    'h|help'            => \$show_help,
    'H|host|hostname=s' => \$hostname,
    'C|community=s'     => \$community,
    'v|version=s'       => \$snmp_version,
    'p|port=s'          => \$port,
    'module=s'          => \$module,
    'list'              => \$list,
    'c|critical=s'      => \$critical,
    'w|warning=s'       => \$warning,
);

sub usage {
  print "$0 [--help] -H <HOST> --module <MODULE> [--list] [-C <COMMUNITY>] [-v <SNMPVERSION>] [-p <PORT>]\n";
}

if(!$list && ($show_help || ! $parse_status || ! $hostname || !$module)) { usage(); exit(); }

my ($session, $error) = Net::SNMP->session(
  -hostname  => $hostname,
  -community => $community,
  -port      => $port,
  -version   => $snmp_version
);

stop("UNKNOWN: $error","UNKNOWN") if(!defined($session));

my $oid_module_name                   = "1.3.6.1.4.1.9804.3.1.1.2.12.46.1.2";
my $oid_cluster_module_storage_status = "1.3.6.1.4.1.9804.3.1.1.2.12.46.1.10";
my $oid_module_usable_space           = "1.3.6.1.4.1.9804.3.1.1.2.12.46.1.5";
my $oid_module_used_space             = "1.3.6.1.4.1.9804.3.1.1.2.12.46.1.29";

my $state = 0;
my %perfdata = ();
my @message = ();

sub snmp_get_table {
  my $oid = shift;
  my $response = $session->get_table($oid);
  if(!defined($response)) {
    print $session->error."\n";
    $session->close();
    exit 3;
  }
  return $response;
}

# Get module names
my $response = snmp_get_table($oid_module_name);
my %resp = %{$response};
my %module_ref = ();
my $module_id = 0;
foreach my $key(keys(%resp)) {
  print "Module ref - $key = ".$resp{$key}."\n" if($verbose || $list);
  if($key =~ /(\d+)$/) {
    my $id = $1;
    $module_ref{$resp{$key}} = $id;
    if($resp{$key} =~ /^$module(\.|$)/i) {
      $module_id = $id;
    }
  }
}

if(!$module_id) {
  print "Unable to find $module in module list.\n";
  exit(3);
}

# Get storage module status
$response = snmp_get_table($oid_cluster_module_storage_status);
%resp = %{$response};
my %storage_status = ();
foreach my $key(keys(%resp)) {
  print "Storage Module status - $key = ".$resp{$key}."\n" if($verbose || $list);
  if($key =~ /(\d+)$/) {
    $storage_status{$1} = $resp{$key};
  }
}

if($storage_status{$module_id} != 1) {
  $state = 2;
}

# Get storage usable space
$response = snmp_get_table($oid_module_usable_space);
%resp = %{$response};
my %usable_space = ();
foreach my $key(keys(%resp)) {
  print "Storage usable space - $key = ".$resp{$key}."\n" if($verbose || $list);
  if($key =~ /(\d+)$/) {
    $usable_space{$1} = $resp{$key};
  }
}

# Get storage usable space
$response = snmp_get_table($oid_module_used_space);
%resp = %{$response};
my %used_space = ();
my %pc_used_space = ();
foreach my $key(keys(%resp)) {
  print "Storage used space - $key = ".$resp{$key}."\n" if($verbose || $list);
  if($key =~ /(\d+)$/) {
    $used_space{$1} = $resp{$key};
    $pc_used_space{$1} = int($used_space{$1} / $usable_space{$1} * 100 + 0.5);
    print "Storage used space (%) = ".$pc_used_space{$1}."\n" if($verbose || $list);
    my $critical_value = ($critical ? int($critical * $usable_space{$1} / 100 + 0.5) : "");
    my $warning_value  = ($warning  ? int($warning  * $usable_space{$1} / 100 + 0.5) : "");
    $perfdata{$1} = "used_space=".$used_space{$1}."kB;$warning_value;$critical_value;0;".$usable_space{$1};
  }
}

print "HP Lefthand module status is ".$message{$state}."|".$perfdata{$module_id}."\n";
exit($state);
