#!/usr/bin/env python
'''
Uses the zabbix python api to retrieve a list the all servers names & ips

Need to configure the server, username & passwords settings
'''

from zabbix_api import ZabbixAPI

server="https://url.of.zabbix.site"
username="user of read on all hosts"
password="pass"

zapi = ZabbixAPI(server=server, path="")
zapi.login(username, password)

hosts=zapi.host.get({"selectInterfaces": "extend", "output": "extend"})
for host in hosts:
	for int in host['interfaces']:
		print "{}\t{}".format(host['host'],host['interfaces'][int]['ip'])
		break
