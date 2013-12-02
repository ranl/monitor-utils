#!/usr/bin/env python

# Info
# parses lmstat utility to get license usage of a specific feature

# Modules
import subprocess
import re
import sys
import os.path

# Settings
lmutil = os.path.dirname(sys.argv[0])

# Validate settings
if len(sys.argv) != 4 :
	print "Syntax error"
	print sys.argv[0] + ' [port] [server name] [feature]'
	quit(3)
if os.path.isfile(lmutil) == False :
	print 'The lmutil binary ' + lmutil + ' does not exists'
	quit(3)

# Vars
port = sys.argv[1]
server = sys.argv[2]
feature = sys.argv[3]
errorString = re.escape('Users of ' + feature + ':  (Error:')

# Initiate lmstat
lmstat = subprocess.Popen([lmutil, 'lmstat' , '-c', port+'@'+server, '-f', feature], shell=False, stdout=subprocess.PIPE, stderr=None, stdin=None)
out = lmstat.communicate()[0].splitlines( )
exitCode = lmstat.returncode
line2Parse = None

# If an erroe occured -> out
if exitCode != 0 :
	for line in out : print line
	quit(1)

# search for the data in stdout
for i in range(len(out)):
	if re.search(re.escape(feature), out[i]) :
		line2Parse = out[i]
		break

# Make sure stdout is valid
if line2Parse == None :
	print 'Can not find feature \"' + feature + '\" in host ' + port+'@'+server
	quit(1)
elif re.search(errorString, line2Parse) :
	print 'Error in license server:'
	print line2Parse
	quit(1)

# Host is up & Data is valid
# parse usage
usage = re.findall(r' \d\d* ', line2Parse)
total = usage[len(usage)-2].strip()
used  = usage[len(usage)-1].strip()

# Output usage
sys.stdout.write('total:'+total + ' ' + 'used:' + used)
quit(0);
