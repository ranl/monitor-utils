#!/usr/bin/env python

'''
Monitor ActiveMQ server via its http web interface
'''

from HTMLParser import HTMLParser
from optparse import OptionParser
import xml.etree.ElementTree as ET
import json
import urllib2
import urllib

# Functions & Classes
def prepareOpts():
	'''
	Parse option from the shell
	'''
	
	cmds = ['queue_prop', 'discovery', 'subscriber_exists']
	datas = ['size', 'consumerCount', 'enqueueCount', 'dequeueCount']

	def err( string ):
		print 'Error: {0}'.format( string )
		parser.print_help()
		print __doc__
		exit(1)

	parser = OptionParser()
	parser.add_option('-s', '--server', dest='server', type='string', help='ActiveMQ fqdn or ip', default='localhost')
	parser.add_option('-p', '--port', dest='port', type='int', help='ActiveMQ web interface port', default=8161)
	parser.add_option('-t', '--timeout', dest='timeout', type='float', help='how many seconds to wait for each http request', default=5)
	parser.add_option('-c', '--cmd', dest='cmd', type='choice', choices=cmds, help='what to check: {0}'.format(cmds) )
	parser.add_option('-q', '--queue', dest='queue', type='string', help='the name of the queue (implies -c queue_prop or -c subscriber_exists)')
	parser.add_option('-d', '--data', dest='data', type='choice', choices=datas, help='the name of the property to return {0} (implies -c queue_prop or -c subscriber_exists)'.format(datas) )
	parser.add_option('-C', '--client', dest='client', type='string', help='the client prefix to search (implies -c subscriber_exists and -q)' )
	(opts, args) = parser.parse_args()

	
	if not opts.cmd:
		err('missing -c')
	
	if opts.cmd == 'queue_prop' and (not opts.queue or not opts.data):
		err('missing -q or -d')
	elif opts.cmd == 'subscriber_exists' and ( not opts.queue or not opts.client ):
		err('missing -q or -C')
	
	return opts

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
		ConsumerHTMLParser.consumers = []
		ConsumerHTMLParser.table = False
		ConsumerHTMLParser.body = False
		ConsumerHTMLParser.tr = False
		ConsumerHTMLParser.td = False
		ConsumerHTMLParser.a = False
	
	def handle_starttag(self, tag, attrs):
		if ConsumerHTMLParser.td and tag == 'a':
			ConsumerHTMLParser.a = True
		elif ConsumerHTMLParser.tr and tag == 'td':
			ConsumerHTMLParser.td = True
		elif ConsumerHTMLParser.body and tag == 'tr':
			ConsumerHTMLParser.tr = True
		elif ConsumerHTMLParser.table and tag == 'tbody':
			ConsumerHTMLParser.body = True
		elif tag == 'table':
			ConsumerHTMLParser.table = ('id', 'messages') in attrs
		
	def handle_data(self, data):
		if ConsumerHTMLParser.a:
			tmp = data.split('-')[0]
			if not tmp in ConsumerHTMLParser.consumers:
				ConsumerHTMLParser.consumers.append( tmp )
			ConsumerHTMLParser.a = False
			ConsumerHTMLParser.td = False
			ConsumerHTMLParser.tr = False
	
	def get_consumers(self):
		return ConsumerHTMLParser.consumers
	

class ActivemqMonitor():
	'''
	Monitor ActiveMQ via http web interface
	'''
	
	def __init__(self, server, port, timeout):
		self.url = 'http://{0}:{1}'.format(server, port)
		self.server = server
		self.port = port
		self.timeout = timeout
	
	def discovery(self, **kwargs):
		'''
		return a json of all the queues in the server
		'''
		ret = {"data": []}
		for q in ET.fromstring( urllib2.urlopen(self.url+'/admin/xml/queues.jsp', timeout=self.timeout).read() ).findall('queue'):
			ret['data'].append( {
				'{#ACTIVEMQ_Q}': q.get('name')
				}
				)
		return ret
	
	def queue_prop(self, **kwargs):
		'''
		return the property of the queue in the server
		'''
		for q in ET.fromstring( urllib2.urlopen(self.url+'/admin/xml/queues.jsp', timeout=self.timeout).read() ).findall('queue'):
			if q.get('name') == kwargs['queue']:
					return int(q.find('stats').get(kwargs['data']))
		
		return 'couldnt find the queue'
	
	def subscriber_exists(self, **kwargs):
		'''
		check if the clientid is configured as a subscriber on the queue
		'''
		
		url = '{0}/admin/queueConsumers.jsp?{1}'.format(
			self.url,
			urllib.urlencode( { 'JMSDestination': kwargs['queue'] } ),
			)
		consumer_parser = ConsumerHTMLParser()
		consumer_parser.feed( urllib2.urlopen(url, timeout=self.timeout).read() )
		
		if kwargs['client'] in consumer_parser.get_consumers():
			return 1
		else:
			return 0
	

# Global Settings
opts = prepareOpts()
monitor = ActivemqMonitor( opts.server, opts.port, opts.timeout )
k = {
	'queue': opts.queue,
	'data': opts.data,
	'client': opts.client,
}

# Do the work
method = getattr(monitor, opts.cmd)
res = method(**k)
if type(res) is dict:
	print json.dumps( res  )
else:
	print res
