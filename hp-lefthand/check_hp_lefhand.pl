#!/usr/bin/perl
use strict;
use Net::SNMP;
use Getopt::Long;
Getopt::Long::Configure ("bundling");

my $verbose      = 0;
my $show_help    = 0;
my $hostname     = 0;
my $community    = 'public';
my $snmp_version = 2;
my $port         = 161;
my $list         = 0;
my $warning      = 0;
my $critical     = 0;
my $element      = 0;
my $element_name = 0;
my $volume_name  = 0;
my $status       = 0;
my @perfdata     = ();

my %message = (0, "OK", 1, "Warning", 2, "CRITICAL", 3, "Unknown");

my $parse_status = GetOptions(
    'd|debug'           => \$verbose,
    'h|help'            => \$show_help,
    'H|host|hostname=s' => \$hostname,
    'C|community=s'     => \$community,
    'v|version=s'       => \$snmp_version,
    'p|port=s'          => \$port,
    'element=s'         => \$element,
    'cluster=s'         => \$element_name,
    'module=s'          => \$element_name,
    'list'              => \$list,
    'c|critical=s'      => \$critical,
    'w|warning=s'       => \$warning,
);

sub usage {
  print "$0 [--help] -H <HOST> --element {cluster|module} [--cluster <CLUSTER>] [--module <MODULE>]
  [--list] [-C <COMMUNITY>] [-v <SNMPVERSION>] [-p <PORT>]

Examples:

Check cluster status:
  check_hp_lefhand.pl -H 127.0.0.1 --cluster myclustername  --element cluster

Check module status:
  check_hp_lefhand.pl -H 127.0.0.1 --module mymoduleaddress --element module

Check cluster volume:
  check_hp_lefhand.pl -H 127.0.0.1 --cluster myclustername  --element volume
\n";
}

if(!$list && ($show_help || ! $parse_status || ! $hostname || !$element)) { usage(); exit(); }

if($element eq "module" && !$element_name) {
  usage();
  print "Please specify module name (--module <MODULE>)\n";
  exit(3);
}

if($element eq "cluster" && !$element_name) {
  usage();
  print "Please specify cluster name (--cluster <CLUSTER>)\n";
  exit(3);
}

if($element eq "volume" && !$element_name) {
  usage();
  print "Please specify cluster name (--cluster <CLUSTER>)\n";
  exit(3);
}

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

# Cluster OIDs
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
# Module OIDs
my $oid_module_name                   = "1.3.6.1.4.1.9804.3.1.1.2.12.46.1.2";
my $oid_cluster_module_storage_status = "1.3.6.1.4.1.9804.3.1.1.2.12.46.1.10";
my $oid_module_usable_space           = "1.3.6.1.4.1.9804.3.1.1.2.12.46.1.5";
my $oid_module_used_space             = "1.3.6.1.4.1.9804.3.1.1.2.12.46.1.29";

my $response;
my %resp;

sub get_element_id {
  my($name) = @_;
  my $oid = $oid_cluster_name; # used for both cluster and volume element
  if($element eq "module") {
    $oid = $oid_module_name;
  }
  $response = snmp_get_table($oid);
  %resp = %{$response};
  foreach my $key(keys(%resp)) {
    print "$element name - $key = ".$resp{$key}."\n" if($verbose || $list);
    next if(!($resp{$key} eq $name) && !($resp{$key} =~ /$element_name\./));
    if($key =~ /(\d+)$/) {
      return $1;
    }
  }
  return -1; # We did not found our object ...
}

my $element_id = get_element_id($element_name);
if($element_id == -1) {
  print "Error while looking for $element '$element_name'\n";
  exit(3);
}

# Test cluster status
sub test_cluster {
  # Get global used space
  $response = snmp_get_table($oid_cluster_used_space);
  %resp = %{$response};
  my $used_space = 0;
  foreach my $key(keys(%resp)) {
    print "Cluster used space - $key = ".$resp{$key}."\n" if($verbose || $list);
    if($key =~ /(\d+)$/) {
      next if($1 != $element_id); # Skipping test for cluster not to be tested
      $used_space = $resp{$key};
    }
  }

  # Get global available space
  $response = snmp_get_table($oid_cluster_total_space);
  %resp = %{$response};
  my $total_space = 0;
  foreach my $key(keys(%resp)) {
    print "Cluster total space - $key = ".$resp{$key}."\n" if($verbose || $list);
    if($key =~ /(\d+)$/) {
      next if($1 != $element_id); # Skipping test for cluster not to be tested
      $total_space = $resp{$key};
      my $critical_value = ($critical ? int($critical * $total_space / 100 + 0.5) : "");
      my $warning_value  = ($warning  ? int($warning  * $total_space / 100 + 0.5) : "");
      push(@perfdata, "used_space=${used_space}kB;$warning_value;$critical_value;0;$total_space");
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
        next if($1 != $element_id); # Skipping test for cluster not to be tested
        push(@perfdata, "$elt=".$resp{$key}."c");
      }
    }
  }

  my $percent_used = sprintf("%.2f", ($used_space / $total_space) * 100);
  print "Percent used for $element_name: $percent_used%\n" if($verbose);
  if($critical && $critical < $percent_used) {
    $status = 2;
  } elsif($warning && $warning < $percent_used) {
    $status = 1;
  }
}

# Test module status
sub test_module {
  # Get storage module status
  $response = snmp_get_table($oid_cluster_module_storage_status);
  %resp = %{$response};
  my %storage_status = ();
  foreach my $key(keys(%resp)) {
    print "Storage Module status - $key = ".$resp{$key}."\n" if($verbose || $list);
    if($key =~ /(\d+)$/) {
      next if($1 != $element_id);
      $status = 2 if($resp{$key} != 1);
    }
  }

  # Get storage usable space
  $response = snmp_get_table($oid_module_usable_space);
  %resp = %{$response};
  my $usable_space = 0;
  foreach my $key(keys(%resp)) {
    print "Storage usable space - $key = ".$resp{$key}."\n" if($verbose || $list);
    if($key =~ /(\d+)$/) {
      next if($1 != $element_id);
      $usable_space = $resp{$key};
    }
  }

  # Get storage usable space
  $response = snmp_get_table($oid_module_used_space);
  %resp = %{$response};
  my $used_space = 0;
  my $pc_used_space = 0;
  foreach my $key(keys(%resp)) {
    print "Storage used space - $key = ".$resp{$key}."\n" if($verbose || $list);
    if($key =~ /(\d+)$/) {
      next if($1 != $element_id);
      $used_space = $resp{$key};
      $pc_used_space = int($used_space / $usable_space * 100 + 0.5);
      print "Storage used space (%) = $pc_used_space%\n" if($verbose || $list);
      my $critical_value = ($critical ? int($critical * $usable_space / 100 + 0.5) : "");
      my $warning_value  = ($warning  ? int($warning  * $usable_space / 100 + 0.5) : "");
      push(@perfdata, "used_space=${used_space}kB;$warning_value;$critical_value;0;$usable_space");
    }
  }
}

if($element eq "cluster") {
  test_cluster();
} elsif($element eq "module") {
  test_module();
} else {
  print "Unknown module type specified: $element\n";
  exit(3);
}

print "HP Lefthand $element is ".$message{$status}."|".join(" ", @perfdata)."\n";
exit($status);
