#!/usr/bin/env python

'''
Nagios compatible plugin to check Apache Modjk

requires
  - Python >= 2.6
  - status worker enable
'''

from optparse import OptionParser
import urllib2
import re
from twisted.plugins.twisted_reactors import default

EXIT_CODE = {
	'OK': 0,
	'WARN': 1,
	'CRIT': 2,
	'UNKNOWN': 3,
}

def prepareOpts():
	'''
	Parse option from the shell
	'''
	
	def help():
		print 'How many workers are in a non-OK state'
		print ''
		parser.print_help()
	
	def err( string ):
		print 'Error: {0}'.format( string )
		help()
		exit(1)
	
	parser = OptionParser()
	parser.add_option('-u', '--url', dest='url', type='string', help='modjk status worker url')
	parser.add_option('-c', '--critical', dest='critical', type='int', help='warning threshold', default=-1)
	parser.add_option('-w', '--warning', dest='warning', type='int', help='critical threshold', default=-1)
	parser.add_option('-t', '--timeout', dest='timeout', type='float', help='how many seconds to wait for each http request', default=5)
	(opts, args) = parser.parse_args()
	
	# Input Validation
	if not opts.url:
		err('missing Modjk Status http url')
	if opts.warning > opts.critical:
		err('-w can not be greater than -c')
	if opts.warning < 0 or opts.critical < 0:
		err('-w and -c must be a positive number')
	
	return opts

def getErrorWorkers(url, timeout):
	'''
	Query the Modjk status worker for bad workers
	'''
	
	ret = []
	response = urllib2.urlopen(url+'?command=list&mime=prop', timeout=timeout).read()
	for line in re.findall( r'worker\..*\.state=.*', response, re.M):
		if not line.endswith('OK'):
			ret.append(
				line.split('.',1)[1].split('.',1)[0]
			)
	return ret


if __name__ == '__main__':
	opts = prepareOpts()
	
	try:
		errorWorkers = getErrorWorkers(
			opts.url, opts.timeout
		)
	except urllib2.URLError as e:
		print 'UNKNOWN: Cant query jkstatus worker for data'
		exit(EXIT_CODE['UNKNOWN'])
	
	count = len(errorWorkers)
	state = ''
	if count < opts.warning:
		state = 'OK'
	elif count >= opts.warning and count < opts.critical:
		state = 'WARN'
	else:
		state = 'CRIT'
	
	print '{0}: {1} workers are in Err state {2}'.format(
		state, count, ','.join(errorWorkers)
	)
	exit(EXIT_CODE[state])
