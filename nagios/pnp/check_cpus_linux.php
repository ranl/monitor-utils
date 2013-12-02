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
define("_WARNRULE", '#FFFF00');
define("_CRITRULE", '#FF0000');
define("_AREA", '#EACC00');
define("_LINE", '#000000');
#
# Initial Logic ...
#

$colors = array(
        'user' => '#00CC00',
        'nice' => '#000000',
        'sys' => '#6600FF',
        'system' => '#6600FF',
        'iowait' => '#FF0000',
        'irq' => '#663300',
        'soft' => '#FFFF00',
        'steal' => '#4596DD',
        'idle' => '#4557DD',
        'guest' => '#A445DD',
        'idle' => '#66FFCC',
);


$current = 0;
$var = 0;

foreach ($DS as $i) {
	if($NAME[$i] == 'user' ) {
		$current = $i;
		$var = 1;
		$vlabel = "";
		if ($UNIT[$i] == "%%") {
			$vlabel = "%";
		}
		else {
			$vlabel = $UNIT[$i];
		}
	
		$opt[$current] = '--lower-limit 0 --upper-limit 100 --vertical-label "' . $vlabel . '" --title "' . $hostname . ' / ' . $servicedesc . '"' . $lower;
	
		$def[$current] = "DEF:var$var=$rrdfile:$DS[$i]:AVERAGE ";
// 		$def[$current] .= "AREA:var$var" . _AREA . ":\"$NAME[$i] \" ";
		$def[$current] .= "LINE3:var$var" . $colors[$NAME[$i]] . ":\"$NAME[$i] \" ";
		$def[$current] .= "GPRINT:var$var:LAST:\"%3.4lf $UNIT[$i] LAST \" ";
		$def[$current] .= "GPRINT:var$var:MAX:\"%3.4lf $UNIT[$i] MAX \" ";
		$def[$current] .= "GPRINT:var$var:AVERAGE:\"%3.4lf $UNIT[$i] AVERAGE \\n\" ";
	} else {
		$var = $var + 1;
		$def[$current] .= "DEF:var$var=$rrdfile:$DS[$i]:AVERAGE ";
		$def[$current] .= "LINE3:var$var" . $colors[$NAME[$i]] . ":\"$NAME[$i] \" ";
		$def[$current] .= "GPRINT:var$var:LAST:\"%3.4lf $UNIT[$i] LAST \" ";
		$def[$current] .= "GPRINT:var$var:MAX:\"%3.4lf $UNIT[$i] MAX \" ";
		$def[$current] .= "GPRINT:var$var:AVERAGE:\"%3.4lf $UNIT[$i] AVERAGE \\n\" ";
	}
}
?>
