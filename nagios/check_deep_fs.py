#!/usr/bin/env python

"""
Monitor a mount on the filesystem and all of it sub mounts
"""

from optparse import OptionParser
import subprocess
import os.path


def parse_args():
    parser = OptionParser()
    parser.add_option('-p', '--path', dest='path', type='string', help='absolute path to check', metavar="FILE")
    parser.add_option('-w', '--warning', dest='warning', type='int', help='critical threshold')
    parser.add_option('-c', '--critical', dest='critical', type='int', help='warning threshold')
    (opts, args) = parser.parse_args()

    if opts.path is None:
        print 'UNKNOWN: -p'
        parser.print_help()
        exit(3)
    if opts.warning is None or opts.critical is None:
        print 'UNKNOWN: missing -w and/or -c'
        parser.print_help()
        exit(3)
    if opts.warning < opts.critical:
        print 'UNKNOWN: -c can not be greater than -w'
        parser.print_help()
        exit(3)
    if opts.path.endswith('/') and opts.path != '/':
        opts.path = opts.path[:-1]
    if not os.path.exists(opts.path):
        print 'UNKNOWN: -p "{0}" must be a valid path'.format(opts.path)
        parser.print_help()
        exit(3)

    return opts


def get_mount_point(loc):
    '''
    Get the mount point of the path
    '''

    mount = os.path.abspath(loc)
    while not os.path.ismount(mount):
        mount = os.path.dirname(mount)

    return mount


def get_df(mount):
    '''
    return a dict of {mount : free space in %}
     - sub mounts of `mount`
     - if mount is not a mount point return it's parent mount point as well
    '''

    res = {}
    real_path = get_mount_point(mount)

    proc = subprocess.Popen(
        'df -P',
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        stdin=None
    )
    df = proc.communicate()[0].splitlines()
    df.pop(0)

    for line in df:
        data = line.split()
        path = data[-1]
        if mount in path or path == real_path:
            res.update({
                path: 100-int(data[-2].replace('%', ''))
            })

    return res


xcode = 0
opts = parse_args()
df = get_df(opts.path)
errors = []

for mount, disk_free in df.items():
    if opts.warning >= disk_free > opts.critical:
        if xcode < 1:
            xcode = 1
        errors.append(mount)
    elif disk_free < opts.critical:
        if xcode < 2:
            xcode = 2
        errors.append(mount)

if xcode == 0:
    msg = 'OK: All mounts are ok'
else:
    if xcode == 1:
        err = 'WARN'
    else:
        err = 'CRIT'
    msg = '{0}: the mount {1} does not have enough disk space'.format(
        err, ','.join(errors)
    )

print msg
exit(xcode)
