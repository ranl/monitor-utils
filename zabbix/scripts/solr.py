#!/usr/bin/env python

'''
Monitor Apache Solr via HTTP for Zabbix
'''

from optparse import OptionParser
import xml.etree.ElementTree as ET
import urllib2


def prepareOpts():
	'''
	Parse option from the shell
	'''
	
	cmds = [
		'ping',
		'dataimportDocumentsProcessed',
		'indexBehindMaster'
		]
	
	def err( string ):
		print 'Error: {0}'.format( string )
		parser.print_help()
		print __doc__
		exit(1)
	
	parser = OptionParser()
	parser.add_option('-u', '--url', dest='url', type='string', help='solr url', default=None)
	parser.add_option('-U', '--user', dest='user', type='string', help='username', default=None)
	parser.add_option('-P', '--passwd', dest='passwd', type='string', help='password', default=None)
	parser.add_option('-t', '--timeout', dest='timeout', type='float', help='how many seconds to wait for each http request', default=5)
	parser.add_option('-c', '--cmd', dest='cmd', type='choice', choices=cmds, help='what to check: {0}'.format(cmds) )
	parser.add_option('-C', '--core', dest='core', type='string', help='core id', default=None)
	parser.add_option('-H', '--handler', dest='handler', type='string', help='dataimport handler name', default=None)
	(opts, args) = parser.parse_args()
	
	if not opts.cmd:
		err('missing -c')
	if (opts.user and not opts.passwd) or (not opts.user and opts.passwd):
		err('missing username or password')
	if not opts.url:
		err('missing solr http url')
	if opts.cmd == 'dataimportDocumentsProcessed':
		if opts.core is None:
			err('missing core id !')
		if opts.handler is None:
			err('missing handler name !')
	
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
	
	def ping(self):
		'''
		Check if solr ping returns True
		'''
		
		ret = 0
		root = self._getXmlData(self.url + '/admin/ping')
		if root is None:
			return 0
		
		if root.find('str').text == 'OK':
			ret = 1
		
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
		
# 		Python 2.7
# 		return int(
# 				root.findall(
# 							"lst[@name='statusMessages']/str[@name='Total Documents Processed']"
# 							)[0].text
# 				)
	
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

# 		Python 2.7
# 		slave = root.findall(
# 							"./*[@name='details']/arr[@name='commits']/lst/long[@name='indexVersion']"
# 							)[0].text
# 		master = root.findall(
# 							"./lst[@name='details']/lst[@name='slave']/lst[@name='masterDetails']/lst[@name='master']/long[@name='replicableVersion']"
# 							)[0].text
		return long(master - slave)
	
	@staticmethod
	def main():
		'''
		Main function
		'''
		
		opts = prepareOpts()
		solr = SolrMonitor( opts.url, opts.timeout, opts.user, opts.passwd )
		
		method = getattr(solr, opts.cmd)
		k = {}
		if opts.core:
			k.update({'core': opts.core})
		if opts.handler:
			k.update({'handler': opts.handler})
		print method(**k)


if __name__ == '__main__':
	SolrMonitor.main()
