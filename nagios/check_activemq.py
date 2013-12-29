#!/usr/bin/env python

'''
Monitor ActiveMQ server via its http web interface
'''

from HTMLParser import HTMLParser
from optparse import OptionParser
import xml.etree.ElementTree as ET
import urllib2
import urllib

EXIT_CODE = {
    'OK': 0,
    'WARN': 1,
    'CRIT': 2,
    'UNKNOWN': 3,
}

def prepareOpts():
    '''
    Parse options from the shell
    '''
    
    cmds = {
        'queues' : 'notify if there is a least one queue with no consumers (--exlcude)',
        'consumer': 'notify if the specific consumers does not consume the queues (--queues, --client)',
    }
    def err( string ):
        print 'Error: {0}'.format( string )
        print __doc__
        parser.print_help()
        print '\nTypes:'
        for k in cmds:
            print '  {0}: {1}'.format(k ,cmds[k])
        exit(1)

    parser = OptionParser()
    parser.add_option('-H', '--server', dest='server', type='string', help='ActiveMQ fqdn or ip', default='localhost')
    parser.add_option('-U', '--user', dest='user', type='string', help='http username', default=None)
    parser.add_option('-P', '--password', dest='password', type='string', help='http password', default=None)
    parser.add_option('-p', '--port', dest='port', type='int', help='ActiveMQ web interface port', default=8161)
    parser.add_option('-t', '--timeout', dest='timeout', type='float', help='how many seconds to wait for each http request', default=5)
    parser.add_option('-T', '--type', dest='type', type='choice', choices=cmds.keys(), help='what to check: {0}'.format(cmds.keys()) )
    parser.add_option('-e', '--exclude', dest='exclude', type='string', help='csv list of queues to exclude (implies -T queues)', default=None )
    parser.add_option('-q', '--queues', dest='queues', type='string', help='csv list of queues (implies -T consumer)', default=None)
    parser.add_option('-c', '--client', dest='client', type='string', help='the client prefix to search (implies -T consumer)', default=None )
    (opts, args) = parser.parse_args()
    
    kargs = {}
    
    if opts.user is None and opts.password is not None:
         err('missing -P')
    elif opts.password is None and opts.user is not None:
        err('missing -U')
    
    if not opts.type:
        err('missing -T')
    elif opts.type == 'consumer':
        if opts.client is None:
            err('missing -c')
        if opts.queues is None:
            err('missing -q')
        else:
            kargs.update({'queues': opts.queues.split(',')})
            kargs.update({'client': opts.client})
    elif opts.exclude is not None:
        kargs.update({'exclude': opts.exclude.split(',')})
            
    
    return (opts, kargs)

class AmqException(Exception):
    def __init__(self, msg, xcode):
        self.msg = msg
        self.xcode = xcode 
    def __str__(self):
        return self.msg
    def getXcode(self):
        return self.xcode
    def getMsg(self):
        return self.msg

class ConsumerHTMLParser(HTMLParser):
    '''
    Parse the consumers id from http://url/admin/queueConsumers.jsp?JMSDestination=QUEUENAME
    '''
    
    consumers = []
    table = False
    body = False
    tr = False
    td = False
    a = False
    
    def reset_vars(self):
        self.consumers = []
        self.table = False
        self.body = False
        self.tr = False
        self.td = False
        self.a = False
    
    def handle_starttag(self, tag, attrs):
        if self.td and tag == 'a':
            self.a = True
        elif self.tr and tag == 'td':
            self.td = True
        elif self.body and tag == 'tr':
            self.tr = True
        elif self.table and tag == 'tbody':
            self.body = True
        elif tag == 'table':
            self.table = ('id', 'messages') in attrs
        
    def handle_data(self, data):
        if self.a:
            if not data in self.consumers:
                self.consumers.append( data )
            self.a = False
            self.td = False
            self.tr = False
    
    def get_consumers(self):
        return self.consumers

class ActivemqMonitor():
    '''
    Monitor ActiveMQ via http web interface
    '''
    
    def __init__(self, server, port, timeout, user=None, password=None, realm='ActiveMQRealm'):
        self.url = 'http://{0}:{1}'.format(server, port)
        self.server = server
        self.port = port
        self.timeout = timeout
        self.user = user
        self.password = password
        self.realm = realm
        if user is not None and password is not None:
            urllib2.install_opener(
                self._auth(
                    self.url, self.user, self.password, self.realm
                )
            )
    
    def _auth(self, uri, user, password, realm):
        '''
        returns a authentication handler.
        '''
    
        basic = urllib2.HTTPBasicAuthHandler()
        basic.add_password(
            realm=realm, uri=uri, user=user, passwd=password
        )
        digest = urllib2.HTTPDigestAuthHandler()
        digest.add_password(
            realm=realm, uri=uri, user=user, passwd=password
        )
        
        return urllib2.build_opener(basic, digest)
    
    def _wget(self, url):
        '''
        create the http request to AMQ web UI
        '''
        
        try:
            ret = urllib2.urlopen(url, timeout=self.timeout).read()
        except urllib2.URLError:
            raise AmqException(
                'UNKNOWN: Could not create http request to ActiveMQ',
                EXIT_CODE['UNKNOWN']
            )
        
        return ret
    
    def _getQueueConsumers(self, queue, parser):
        '''
        Get the parsed data of the queue
        '''
        
        url = '{0}/admin/queueConsumers.jsp?{1}'.format(
            self.url,
            urllib.urlencode( { 'JMSDestination': queue } ),
        )
        parser.reset_vars()
        parser.feed( self._wget(url) )
        return parser.get_consumers()
    
    def _eval_queues(self, res, opts):
        if res:
            return {
                'msg': 'CRIT: the following queues are not consumed {0}'.format(','.join(res)),
                'exit': EXIT_CODE['CRIT']
            }
        else:
            return {
                'msg': 'OK: All the queues are consumed',
                'exit': EXIT_CODE['OK']
            }
    
    def _eval_consumer(self, res, opts):
        if res:
            return {
                'msg': 'CRIT: the following queues are not consumed by {0} {1}'.format(
                    opts.client, ','.join(res)
                ),
                'exit': EXIT_CODE['CRIT']
            }
        else:
            return {
                'msg': 'OK: {0} is consuming all of its queues'.format(opts.client),
                'exit': EXIT_CODE['OK']
            }
    
    def queues(self, exclude=[]):
        '''
        return all the queues with zero consumers
        '''
        errors = []
        url = '{0}/admin/xml/queues.jsp'.format(self.url, )
        html = self._wget(url)
        for q in ET.fromstring( html ).findall('queue'):
            if q.get('name') not in exclude and int(q.find('stats').get('consumerCount')) <= 0:
                errors.append(q.get('name'))
        
        return errors
    
    def consumer(self, client, queues):
        '''
        check if the clientid is configured as a subscriber on the queue
        '''
        
        missing = list(queues)
        parser = ConsumerHTMLParser()
        for queue in queues:
            for consumer in self._getQueueConsumers(queue, parser):
                if client in consumer:
                    missing.remove(queue)
                    break
        
        return missing
    
    @staticmethod
    def main():
        '''
        Main function
        '''
        (opts, kargs) = prepareOpts()
        amq = ActivemqMonitor(
            opts.server, opts.port, opts.timeout, opts.user, opts.password
        )
        
        method = getattr(amq, opts.type)
        try:
            res = method(**kargs)
        except AmqException as e:
            print e.getMsg()
            exit(e.getXcode())
        
        eval_method = getattr(
            amq, '_eval_{0}'.format(opts.type)
        )
        ret = eval_method(res, opts)
        print ret['msg']
        exit(ret['exit'])
    
if __name__ == '__main__':
    ActivemqMonitor.main()
