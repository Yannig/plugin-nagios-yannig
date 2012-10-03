#!/usr/bin/perl

use strict;
use Getopt::Long;

my $script    = 0;
my $label     = 0;
my $warning   = 0;
my $critical  = 0;
my $state     = 0;
my $show_help = 0;

my %message = (0, "OK", 1, "Warning", 2, "CRITICAL");

sub usage {
  print "$0 [-h] --script <SCRIPT> [--label <LABEL>] -w <WARN> -c <CRIT>\n";
}

GetOptions(
  "h|help" =>            \$show_help,
  "script=s" =>          \$script,
  "label=s" =>           \$label,
  "w|warn|warning=s" =>  \$warning,
  "c|crit|critical=s" => \$critical,
);

if($show_help || !$script) {
  usage();
  exit(0);
}

$label = $script if(!$label);
my @exec_output = `$script 2>&1`;

my($test_count, $time)= (0, 0);

# Test output
if(!($exec_output[scalar(@exec_output) -1] =~ /^OK$/)) {
  print "Error while launching '$label' scenario\n";
  exit(2);
}
my @tmp = grep(/^Ran/, @exec_output);
my $time = $tmp[0];
if($time =~ /Ran (\d+) test in (\d+\.\d+)s/) {
  ($test_count, $time) = ($1, $2);
}

if($critical && $critical < $time) {
  $state = 2;
} elsif($warning && $warning < $time) {
  $state = 1;
}
print "Selenium test ".$message{$state}." ($label)|time=${time}s test_count=$test_count\n";
exit($state);
