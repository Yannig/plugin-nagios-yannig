<?php

##   This program is free software; you can redistribute it and/or modify
##   it under the terms of the GNU General Public License as published by
##   the Free Software Foundation; either version 2 of the License, or
##   (at your option) any later version.
##
##   This program is distributed in the hope that it will be useful,
##   but WITHOUT ANY WARRANTY; without even the implied warranty of
##   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##   GNU General Public License for more details.
##
##   You should have received a copy of the GNU General Public License
##   along with this program; if not, write to the Free Software
##   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

##   PNP Template for check_cpu.pl
	##   Author: Yannig Perre (http://lesaventuresdeyannigdanslemondeit.blogspot.fr/)

if($LABEL[1] != "user") {
  include_once("templates.dist/default.php");
  return;
}

$opt[1] = "--vertical-label \"CPU [%]\" -u 100 -l 0 -r --title \"CPU Usage for $hostname / $servicedesc\" ";

$def[1]  =  rrd::def("used",    $RRDFILE[1], $DS[1]);
$def[1] .=  rrd::def("nice",    $RRDFILE[2], $DS[2]);
$def[1] .=  rrd::def("sys",     $RRDFILE[3], $DS[3]);
$def[1] .=  rrd::def("iowait",  $RRDFILE[4], $DS[4]);
$def[1] .=  rrd::def("irq",     $RRDFILE[5], $DS[5]);
$def[1] .=  rrd::def("softirq", $RRDFILE[6], $DS[6]);
$def[1] .=  rrd::def("idle",    $RRDFILE[7], $DS[7]);

$def[1] .= rrd::area  ("used",    "#E80C3E", "user   ", "STACK");; 
$def[1] .= rrd::gprint("used",    array("LAST", "AVERAGE", "MAX"), "%6.2lf%% ");

$def[1] .= rrd::area  ("nice",    "#E8630C", "nice   ", "STACK"); 
$def[1] .= rrd::gprint("nice",    array("LAST", "AVERAGE", "MAX"), "%6.2lf%% ");

$def[1] .= rrd::area  ("sys",     "#008000", "sys    ", "STACK");
$def[1] .= rrd::gprint("sys",     array("LAST", "AVERAGE", "MAX"), "%6.2lf%% ");

$def[1] .= rrd::area  ("iowait",  "#0CE84D", "iowait ", "STACK");
$def[1] .= rrd::gprint("iowait",  array("LAST", "AVERAGE", "MAX"), "%6.2lf%% ");

$def[1] .= rrd::area  ("irq",     "#3E00FF", "irq    ", "STACK");
$def[1] .= rrd::gprint("irq",     array("LAST", "AVERAGE", "MAX"), "%6.2lf%% ");

$def[1] .= rrd::area  ("softirq", "#1CC8E8", "softirq", "STACK");
$def[1] .= rrd::gprint("softirq", array("LAST", "AVERAGE", "MAX"), "%6.2lf%% ");

$def[1] .= rrd::area  ("idle",    "#FFFFFF", "idle   ", "STACK"); 
$def[1] .= rrd::gprint("idle",    array("LAST", "AVERAGE", "MAX"), "%6.2lf%% ");
?>
