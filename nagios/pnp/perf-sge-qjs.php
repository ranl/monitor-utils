<?php
#
# Copyright (c) 2006-2008 Joerg Linge (http://www.pnp4nagios.org)
# Default Template used if no other template is found.
# Don`t delete this file ! 
# $Id: default.php 555 2008-11-16 16:35:59Z pitchfork $
#
#
# Define some colors ..
#

$queue_temp = explode("_", $NAME[1]);
$queue = "$queue_temp[0]";

$opt[1] = '--vertical-label "' . $vlabel . '" --title "' . $queue . ' Usage"' . $lower;

$def[1] =  "DEF:var1=$rrdfile:$DS[1]:AVERAGE " ;
$def[1] .= "DEF:var2=$rrdfile:$DS[2]:AVERAGE " ;
	
$def[1] .= "AREA:var2#FFCC99:\"Total \" " ;
$def[1] .= "GPRINT:var2:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var2:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var2:MAX:\"%6.2lf max\\n\" ";
	
$def[1] .= "AREA:var1#00FF00:Used ";
$def[1] .= "LINE:var1#000000 " ;
$def[1] .= "GPRINT:var1:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var1:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var1:MAX:\"%6.2lf max\\n\" " ;

$def[1] .= 'COMMENT:"Default Template\r" ';
$def[1] .= 'COMMENT:"Check Command ' . $TEMPLATE[1] . '\r" ';

$opt[2] = '--vertical-label "' . $vlabel . '" --title "' . $queue . ' Job Average Waiting Time"' . $lower;
$def[2] = "DEF:var3=$rrdfile:$DS[3]:AVERAGE " ;
$def[2] .= "AREA:var3#00FF00:seconds ";
$def[2] .= "LINE:var3#000000 " ;
$def[2] .= "GPRINT:var3:LAST:\"%6.2lf last\" " ;
$def[2] .= "GPRINT:var3:AVERAGE:\"%6.2lf avg\" " ;
$def[2] .= "GPRINT:var3:MAX:\"%6.2lf max\\n\" " ;
$def[2] .= 'COMMENT:"Check Command ' . $TEMPLATE[2] . '\r" ';

?>
