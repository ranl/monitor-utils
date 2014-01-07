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

EXIT_CODE = {
    'OK': 0,
    'WARN': 1,
    'CRIT': 2,
    'UNKNOWN': 3,
}


def prepare_opts():
    '''
    Parse option from the shell
    '''
    
    def help():
        print 'How many workers are in OK state and Activated'
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
    if opts.warning < opts.critical:
        err('-w can not be smaller than -c')
    if opts.warning < 0 or opts.critical < 0:
        err('-w and -c must be a positive number')
    
    return opts


def get_error_workers(url, timeout):
    '''
    Query the Modjk status worker for bad workers
    '''

    get_node = re.compile(r'Member: name=(.*) type=')
    ret = set([])
    total = 0
    response = urllib2.urlopen(url+'?mime=txt', timeout=timeout).read()
    for member in re.findall( r'^Member: .*', response, re.M):
        total += 1
        if 'state=OK' in member and 'activation=ACT' in member:
            ret.add(
                get_node.search(member).groups(0)[0]
            )
    return (list(ret), total)


if __name__ == '__main__':
    opts = prepare_opts()
    
    try:
        (errorWorkers, total) = get_error_workers(
            opts.url, opts.timeout
        )
    except urllib2.URLError as e:
        print 'UNKNOWN: Cant query jkstatus worker for data'
        exit(EXIT_CODE['UNKNOWN'])
    
    count = len(errorWorkers)
    state = ''
    if count > opts.warning or (opts.warning == 1 and count == 1):
        state = 'OK'
    elif opts.warning >= count > opts.critical:
        state = 'WARN'
    else:
        state = 'CRIT'
    
    print '{0}: {1}/{2} workers are OK and ACT {3}'.format(
        state, count, total, ','.join(errorWorkers)
    )
    exit(EXIT_CODE[state])
