#!/usr/bin/env python27

'''
Info:
This python script is used as an Zabbix alert script to create simple RSS feed
of the notifications

To make it work:
- Configure the Settings section in the script
- add as an alert script in zabbix
 - notice that the subject won't be in the rss, only the message
- add the xml code below to the rssFile
<rss version="2.0">
        <channel>
                <language>en</language>
        </channel>
</rss>
'''

# libs
import xml.etree.ElementTree as ET
import datetime
import sys

# Settings
link_data = "https://path/to/zabbix/tr_status.php?form_refresh=1&groupid=0&hostid=0&fullscreen=1"
rssFile = "/path/to/zabbix/web/interface/rss"
item_2_keep = 20
title_data = sys.argv[3]

# get root
tree = ET.parse(rssFile)
root = tree.getroot()

# update time
root[0][4].text = str(datetime.datetime.now())

# add new item
new_item = ET.SubElement(root[0],"item")
title = ET.SubElement(new_item,"title")
title.text = str(title_data)
link = ET.SubElement(new_item,"link")
link.text = str(link_data)

# keep only x latest items
itemRoot = root[0]
items = itemRoot.findall('item')
i=0
for item in items:
	i=i+1
	if i > len(items)-item_2_keep:
		break
	itemRoot.remove(item)


# write to file
tree.write(rssFile)
