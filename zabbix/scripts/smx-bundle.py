#!/usr/bin/env python
'''
Info:
check via ssh if a bundle is in Active mode
in an Apache ServiceMix setup
'''

import argparse
import subprocess
import re

# Functions
def myShell(cmd):
    """
    will execute the cmd in a Shell and will return the hash res
    res['out'] -> array of the stdout (bylines)
    res['err'] -> same as above only stderr
    res['exit'] -> the exit code of the command
    """

    res = {}
    proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=None)
    tmp = proc.communicate()
    res['out'] = tmp[0].splitlines()
    res['err'] = tmp[1].splitlines()
    res['exit'] = proc.returncode
    return res


# Parser
parser = argparse.ArgumentParser(description="check via ssh-smx if the bundle is in Active mode in an Apache ServiceMix setup")
parser.add_argument("srv", type=str, help="hostname or ip of the smx server")
parser.add_argument("port", type=int, help="port of the smx daemon")
parser.add_argument("user", type=str, help="servicemix username")
parser.add_argument("passwd", type=str, help="servicemix password")
parser.add_argument("bundle", type=str, help="bundle name")
args = parser.parse_args()

# Settings
ssh = "timeout 3 sshpass -p "+str(args.passwd)+" ssh -l "+str(args.user)+" -o ConnectTimeout=3 -o StrictHostKeyChecking=no -p "+str(args.port)+" "+args.srv+" osgi:list"

# Start script
output = myShell(ssh)
if output['exit'] != 0:
	print 0
	exit(1)

output['out'].pop(0)
output['out'].pop(0)

found = False
for line in output['out']:
	if re.search('\[Active', line):
		linePars = line.split("]")
		name = linePars.pop()
		name.strip()
		if re.search(re.escape(args.bundle), name):
			found = True
			break

if found:
	print 1
else:
	print 0

