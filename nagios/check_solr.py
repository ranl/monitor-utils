#!/usr/bin/env python

'''
Nagios compatible plugin to check Solr via Solr HTTP API

require Python >= 2.6 
'''

from optparse import OptionParser
import xml.etree.ElementTree as ET
import urllib2
import tempfile
import os.path

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
    
    cmds = {
        'ping' : 'create a ping to solr API',
        'dataimportDocumentsProcessed': 'check that the dataimport handler is not processing the same document for too long',
        'indexBehindMaster': 'check the difference between the slave index and the master'
    }
    epliog = 'Type of Checks:'
    for k in cmds:
        epliog += '\n  {0}:\t{1}'.format(k, cmds[k])
    
    def help():
        parser.print_help()
        print ''
        print epliog
    
    def err( string ):
        print 'Error: {0}'.format( string )
        help()
        exit(1)
    
    parser = OptionParser()
    parser.add_option('-u', '--url', dest='url', type='string', help='solr url', default=None)
    parser.add_option('-U', '--user', dest='user', type='string', help='username', default=None)
    parser.add_option('-P', '--passwd', dest='passwd', type='string', help='password', default=None)
    parser.add_option('-t', '--timeout', dest='timeout', type='float', help='how many seconds to wait for each http request', default=5)
    parser.add_option('-T', '--type', dest='type', type='choice', choices=cmds.keys(), help='what to check: {0}'.format(', '.join(cmds.keys())) )
    parser.add_option('-C', '--core', dest='core', type='string', help='core id', default=None)
    parser.add_option('-d', '--handler', dest='handler', type='string', help='dataimport handler name', default=None)
    parser.add_option('-c', '--critical', dest='critical', type='int', help='warning threshold (implies -T indexBehindMaster)', default=None)
    parser.add_option('-w', '--warning', dest='warning', type='int', help='critical threshold (implies -T indexBehindMaster)', default=None)
    parser.add_option('-m', '--tmpdir', dest='tmpdir', type='string', help='absolute path to a writeable directory on the server', default=tempfile.gettempdir())
    (opts, args) = parser.parse_args()
    
    # Input Validation
    if not opts:
        help()
        exit(1)
    if not opts.type:
        err('missing -T')
    if (opts.user and not opts.passwd) or (not opts.user and opts.passwd):
        err('missing username or password')
    if not opts.url:
        err('missing solr http url')
    if opts.type == 'dataimportDocumentsProcessed':
        if opts.core is None:
            err('missing core id !')
        if opts.handler is None:
            err('missing handler name !')
    if opts.type == 'indexBehindMaster':
        if opts.critical is None or opts.warning is None:
            err('missing -w or -c')
        if opts.warning > opts.critical:
            err('-w can not be greater than -c')
    
    return opts


class SolrMonitor():
    '''
    Monitor Apache Solr via http
    '''
    
    def __init__(self, url, timeout=5, username=None, passwd=None):
        self.url = url
        self.timeout = timeout
        self.username = username
        self.passwd = passwd
        self.memfile = 'check_solr_data'
        
        if self.url.endswith('/'):
            self.url = self.url[:-1]
        
        self._get_auth()
    
    def _get_auth(self):
        '''
        Build an Auth opener for HTTP connection
        '''
        if not self.username or not self.passwd:
            return
        basic = urllib2.HTTPBasicAuthHandler()
        basic.add_password(
                        realm='Solr',
                        uri=self.url,
                        user=self.username,
                        passwd=self.passwd
                        )
        digest = urllib2.HTTPDigestAuthHandler()
        digest.add_password(
                        realm='Solr',
                        uri=self.url,
                        user=self.username,
                        passwd=self.passwd
                        )
        
        urllib2.install_opener(
                            urllib2.build_opener(basic, digest))
    
    def _getXmlData(self, url):
        '''
        create an http request to url and return the data
        in case of a problem return None
        '''
        
        try:
            return ET.fromstring(
                                urllib2.urlopen(
                                            url,
                                            timeout=self.timeout
                                            ).read()
                                )
        except urllib2.URLError:
            return None
    
    def _eval_ping(self, res, opts):
        '''
        Evaluate the ping test
        '''
        
        if res:
            return {
                'exit': EXIT_CODE['OK'],
                'msg': 'OK: Solr Ping is up'
            }
        else:
            return {
                'exit': EXIT_CODE['CRIT'],
                'msg': 'CRIT: Solr Ping is down'
            }
    
    def _eval_dataimportDocumentsProcessed(self, res, opts):
        '''
        Evaluate the dataimportDocumentsProcessed test
        '''
        firstTimeResponse = {
            'exit': EXIT_CODE['UNKNOWN'],
            'msg': 'UNKNOWN: looks like the first time we are using this check, creating local cache'
        }
        memFile = os.path.join(opts.tmpdir, self.memfile)
        if not os.path.isfile(memFile):
            with open( memFile, 'w' ) as f:
                f.write(str(res))
            return firstTimeResponse
        
        if res < 0:
            return {
                'exit': EXIT_CODE['UNKNOWN'],
                'msg': 'UNKNOWN: could not query solr for index status'
            }
        
        fh = open( memFile, 'r+' )
        prev = fh.read()
        fh.seek(0)
        fh.write(str(res))
        fh.close()
        if not prev:
            return firstTimeResponse
        prev = int(prev)
        
        if prev != res or res == 0:
            return {
                'exit': EXIT_CODE['OK'],
                'msg': 'OK: Solr is indexing {0} docs now and before {1}'.format(
                    res, prev
                )
            }
        else:
            return {
                'exit': EXIT_CODE['CRIT'],
                'msg': 'CRIT: Solr is still indexing {0} docs since the last check'.format(res)
            }
        
    def _eval_indexBehindMaster(self, res, opts):
        '''
        Evaluate the indexBehindMaster test
        '''
        
        msg=''
        if res < opts.warning:
            msg='OK'
        elif res >= opts.warning and res <= opts.critical:
            msg='WARN'
        else:
            msg='CRIT'
        return {
            'exit': EXIT_CODE[msg],
            'msg': '{0}: Solr Slave is {1} behind then master'.format(
                msg, res
            )
        }
    
    def ping(self):
        '''
        Check if solr ping returns True
        '''
        
        ret = False
        root = self._getXmlData(self.url + '/admin/ping')
        if root is None:
            return False
        
        if root.find('str').text == 'OK':
            ret = True
        
        return ret
    
    def dataimportDocumentsProcessed(self, core, handler):
        '''
        Return the number of processed documents
        from the dataimport handler
        
        url: http://solr:port/solr/core0/dataimportName?command=status
        '''
        
        url = '{0}/{1}/{2}?command=status'.format(
            self.url,
            core,
            handler
        )
        root = self._getXmlData(url)
        if root is None:
            return -1
        
        for lst in root.findall('lst'):
            if lst.attrib['name'] == 'statusMessages':
                for str in lst.findall('str'):
                    if str.attrib['name'] == 'Total Documents Processed':
                        return int(str.text)
        
        return -1
        
#         Python 2.7
#         return int(
#                 root.findall(
#                             "lst[@name='statusMessages']/str[@name='Total Documents Processed']"
#                             )[0].text
#                 )
    
    def indexBehindMaster(self):
        '''
        Returns the difference bewteen the slave index
        and the master replicable index
        '''
        
        slave = None
        master = None
        root = self._getXmlData(
                            self.url + '/replication?command=details'
                            )
        if root is None:
            return -1
        
        for lst in root.findall('lst'):
            if lst.attrib['name'] == 'details':
                
                # Slave
                for lng in lst.findall('long'):
                    if lng.attrib['name'] == 'indexVersion':
                        slave = long(lng.text)
                        break

                # Master
                for lstm in lst.findall('lst'):
                    if lstm.attrib['name'] == 'slave':
                        for lstms in lstm.findall('lst'):
                            if lstms.attrib['name'] == 'masterDetails':
                                for lstMaster in lstms.findall('lst'):
                                    if lstMaster.attrib['name'] == 'master':
                                        for rep in lstMaster.findall('long'):
                                            if rep.attrib['name'] == 'replicableVersion':
                                                master = long(rep.text)
                                                break
                
            if master and slave:
                break

#         Python 2.7
#         slave = root.findall(
#                             "./*[@name='details']/arr[@name='commits']/lst/long[@name='indexVersion']"
#                             )[0].text
#         master = root.findall(
#                             "./lst[@name='details']/lst[@name='slave']/lst[@name='masterDetails']/lst[@name='master']/long[@name='replicableVersion']"
#                             )[0].text
        return long(master - slave)
    
    @staticmethod
    def main():
        '''
        Main function
        '''
        
        opts = prepareOpts()
        solr = SolrMonitor( opts.url, opts.timeout, opts.user, opts.passwd )
        
        method = getattr(solr, opts.type)
        k = {}
        if opts.core:
            k.update({'core': opts.core})
        if opts.handler:
            k.update({'handler': opts.handler})
        res = method(**k)
        
        eval_method = getattr(
            solr, '_eval_{0}'.format(opts.type)
        )
        ret = eval_method(res, opts)
        print ret['msg']
        exit(ret['exit'])
        


if __name__ == '__main__':
    SolrMonitor.main()
