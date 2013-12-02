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
// define("_WARNRULE", '#FFFF00');
// define("_CRITRULE", '#FF0000');
// define("_AREA", '#EACC00');
// define("_LINE", '#000000');
#
# Initial Logic ...
#

$opt[1] = "--vertical-label Memory -l0  --title \"$servicedesc\" ";
#
#
#
$def[1] =  "DEF:var1=$rrdfile:$DS[1]:AVERAGE " ;
$def[1] .= "DEF:var2=$rrdfile:$DS[2]:AVERAGE " ;
$def[1] .= "DEF:var3=$rrdfile:$DS[3]:AVERAGE " ;
$def[1] .= "DEF:var4=$rrdfile:$DS[4]:AVERAGE " ;
$def[1] .= "DEF:var5=$rrdfile:$DS[5]:AVERAGE " ;

$def[1] .= "AREA:var1#FFCC99:\"$NAME[1] \" " ;
$def[1] .= "GPRINT:var1:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var1:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var1:MAX:\"%6.2lf max\\n\" ";

$def[1] .= "LINE2:var2#00FF00:\"$NAME[2] \" " ;
$def[1] .= "GPRINT:var2:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var2:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var2:MAX:\"%6.2lf max\\n\" " ;

$def[1] .= "LINE2:var3#FF0000:\"$NAME[3] \" " ;
$def[1] .= "GPRINT:var3:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var3:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var3:MAX:\"%6.2lf max\\n\" " ;

$def[1] .= "LINE2:var4#0000FF:\"$NAME[4] \" " ;
$def[1] .= "GPRINT:var4:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var4:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var4:MAX:\"%6.2lf max\\n\" " ;

$def[1] .= "LINE2:var5#FFFF00:\"$NAME[5] \" " ;
$def[1] .= "GPRINT:var5:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var5:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var5:MAX:\"%6.2lf max\\n\" " ;

$def[$i] .= 'COMMENT:"Check Command ' . $TEMPLATE[$i] . '\r" ';
?>
