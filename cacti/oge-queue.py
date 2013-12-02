#!/bin/env python

# Info:
# Get queue usage via qstat -g c command
# Note: it will exclude host in error/disable hosts
#
# Settings:
# add the cacti server as submit host
# set the gridSettings variable

# Modules
import subprocess
import sys

# Settings
gridSettings = '/path/to/common/settings.sh'

if len(sys.argv) != 2:
	print "Syntax error"
	print sys.argv[0] + ' [full queue name]'
	quit(1)

# Vars
queue = sys.argv[1]
jobsCounter = 0
foundQueue = False
running = 0
total = 0

# Initiate qstat -g c
qstat = subprocess.Popen('source ' + gridSettings + '; ' + 'qstat -g c', shell=True, stdout=subprocess.PIPE, stderr=None, stdin=None)
out = qstat.communicate()[0].splitlines( )
exitCode = qstat.returncode

# If an error occured -> out
if exitCode != 0 :
	for line in out : print line
	quit(1)

# Parse out
for i in range(len(out)):
	queueInfo = out[i].split()
	if queueInfo[0] == queue:
		foundQueue = True
		total = int(queueInfo[2]) + int(queueInfo[4])
		running = int(queueInfo[2])

# Print Result
if foundQueue :
	sys.stdout.write('total:'+str(total) + ' ' + 'running:'+str(running))
else :
	sys.stdout.write('-1')
	quit(1)
