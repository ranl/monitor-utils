#!/bin/env python

# Info
# Check via the qhost command the number a running jobs on a specific execution host
#
# Settings
# 1. set the gridSettings variable
# 2. queues can be excluded by settings the excludeQueues list
# 3. the cacti server needs to be configured as the submit host (qconf -as CACTISERVER)

# Modules
import subprocess
import re
import string
import sys

# Exclude function
def isInList(string, dst) :
	res = False
	for i in range(len(dst)):
		if string == dst[i]:
			res = True
			break
	return res


# Settings
gridSettings = '/path/to/common/settings.sh'
excludeQueues = []

# Validate command arguments
if len(sys.argv) != 2:
	print "Syntax error"
	print sys.argv[0] + ' [execHost]'
	quit(1)

# Vars
execHost = sys.argv[1]
execHostEscaped = ''
foundExecHost = False
jobsCounter = 0

# Initiate qhost -q
qhost = subprocess.Popen('source ' + gridSettings + '; ' + 'qhost -q', shell=True, stdout=subprocess.PIPE, stderr=None, stdin=None)
out = qhost.communicate()[0].splitlines( )
exitCode = qhost.returncode

# If an error occured -> quit
if exitCode != 0 :
	for line in out : print line
	quit(1)

# Parse out
execHostEscaped = re.escape(execHost) + ' '
for i in range(len(out)):
	if foundExecHost and re.search('^ ' ,out[i]) :
		if not isInList(out[i].split()[0], excludeQueues):
			jobsCounter += int(string.split(out[i].split()[2],'/')[0])
	elif foundExecHost and re.search('^\w' ,out[i]) :
		break
	else :
		if re.search(execHostEscaped, out[i]) :
			foundExecHost = True

# Print Result
if foundExecHost :
	sys.stdout.write('jobs:'+str(jobsCounter))
else :
	sys.stdout.write('-1')
	quit(1)
