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

$opt[1] = "--vertical-label bit --title \"$servicedesc\" --lower-limit 0 ";
#
#
#
$def[1] =  "DEF:var1=$rrdfile:$DS[1]:AVERAGE " ;
$def[1] .= "DEF:var2=$rrdfile:$DS[2]:AVERAGE " ;

$def[1] .= "AREA:var1#00FF00:\"In \" " ;
$def[1] .= "LINE:var1#000000 " ;
$def[1] .= "GPRINT:var1:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var1:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var1:MAX:\"%6.2lf max\\n\" ";

$def[1] .= "LINE3:var2#0000FF:\"Out \" " ;
$def[1] .= "GPRINT:var2:LAST:\"%6.2lf last\" " ;
$def[1] .= "GPRINT:var2:AVERAGE:\"%6.2lf avg\" " ;
$def[1] .= "GPRINT:var2:MAX:\"%6.2lf max\\n\" " ;

?>
