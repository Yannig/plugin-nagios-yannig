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
my $cluster_name = 0;
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
    'cluster=s'         => \$cluster_name,
    'list'              => \$list,
    'c|critical=s'      => \$critical,
    'w|warning=s'       => \$warning,
);

sub usage {
  print "$0 [--help] -H <HOST> --cluster <CLUSTER> [--list] [-C <COMMUNITY>] [-v <SNMPVERSION>] [-p <PORT>]\n";
}

if(!$list && ($show_help || ! $parse_status || ! $hostname || !$cluster_name)) { usage(); exit(); }

my ($session, $error) = Net::SNMP->session(
  -hostname  => $hostname,
  -community => $community,
  -port      => $port,
  -version   => $snmp_version
);

stop("UNKNOWN: $error","UNKNOWN") if(!defined($session));

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

my $oid_cluster_name            = "1.3.6.1.4.1.9804.3.1.1.2.12.48.1.2";
my $oid_cluster_total_space     = "1.3.6.1.4.1.9804.3.1.1.2.12.48.1.29";
my $oid_cluster_used_space      = "1.3.6.1.4.1.9804.3.1.1.2.12.48.1.31";
my $oid_cluster_io_read         = "1.3.6.1.4.1.9804.3.1.1.2.12.48.1.20";
my $oid_cluster_io_write        = "1.3.6.1.4.1.9804.3.1.1.2.12.48.1.21";
my $oid_cluster_bytes_read      = "1.3.6.1.4.1.9804.3.1.1.2.12.48.1.22";
my $oid_cluster_bytes_write     = "1.3.6.1.4.1.9804.3.1.1.2.12.48.1.23";
my $oid_cluster_latency_read    = "1.3.6.1.4.1.9804.3.1.1.2.12.48.1.26";
my $oid_cluster_latency_write   = "1.3.6.1.4.1.9804.3.1.1.2.12.48.1.27";
my $oid_cluster_stat_cache_hits = "1.3.6.1.4.1.9804.3.1.1.2.12.48.1.28";

# Get global cluster name
my $response = snmp_get_table($oid_cluster_name);
my %resp = %{$response};
my %cluster_id = ();
foreach my $key(keys(%resp)) {
  print "Cluster name - $key = ".$resp{$key}."\n" if($verbose || $list);
  if($key =~ /(\d+)$/) {
    $cluster_id{$resp{$key}} = $1;
  }
}

# Get global used space
$response = snmp_get_table($oid_cluster_used_space);
%resp = %{$response};my %perfdata = ();

my %used_space = ();
foreach my $key(keys(%resp)) {
  print "Cluster used space - $key = ".$resp{$key}."\n" if($verbose || $list);
  if($key =~ /(\d+)$/) {
    $used_space{$1} = $resp{$key};
  }
}

# Get global available space
$response = snmp_get_table($oid_cluster_total_space);
%resp = %{$response};
my %total_space = ();
my %perfdata = ();
foreach my $key(keys(%resp)) {
  print "Cluster total space - $key = ".$resp{$key}."\n" if($verbose || $list);
  if($key =~ /(\d+)$/) {
    $total_space{$1} = $resp{$key};
    my $critical_value = ($critical ? int($critical * $total_space{$1} / 100 + 0.5) : "");
    my $warning_value  = ($warning  ? int($warning  * $total_space{$1} / 100 + 0.5) : "");
    $perfdata{$1} = "used_space=".$used_space{$1}."kB;$warning_value;$critical_value;0;".$total_space{$1};
  }
}

exit(0) if($list);

# Get io stats
my %stats = (
  "IO-read-count",  $oid_cluster_io_read,
  "IO-write-count", $oid_cluster_io_write,
  "Bytes-read",     $oid_cluster_bytes_read,
  "Bytes-write",    $oid_cluster_bytes_write,
  "latency-read",   $oid_cluster_latency_read,
  "latency-write",  $oid_cluster_latency_write,
  "cache-hits",     $oid_cluster_stat_cache_hits,
);

foreach my $elt(sort(keys(%stats))) {
  $response = snmp_get_table($stats{$elt});
  %resp = %{$response};
  foreach my $key(keys(%resp)) {
    print "Cluster $elt - $key = ".$resp{$key}."\n" if($verbose);
    if($key =~ /(\d+)$/) {
      $perfdata{$1} .= " $elt=".$resp{$key}."c";
    }
  }
}

my $status = 0;
my @clusters = ($cluster_name);
my %percent_used = ();
my @perfdata = ();

$percent_used{$cluster_name} = sprintf("%.2f", ($used_space{$cluster_id{$cluster_name}} / $total_space {$cluster_id{$cluster_name}}) * 100);
print "Percent used for $cluster_name: ".$percent_used{$cluster_name}."\n" if($verbose);
if($critical && $critical < $percent_used{$cluster_name}) {
  $status = 2;
} elsif($warning && $warning < $percent_used{$cluster_name}) {
  $status = 1;
}

print "HP Lefthand disk space is ".$message{$status}."|".$perfdata{$cluster_id{$cluster_name}}."\n";
exit($status);
