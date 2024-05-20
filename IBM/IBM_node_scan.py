import datetime
from collections import defaultdict

import urllib.request
import xml.etree.ElementTree as ET



def call_API(url):
	response = urllib.request.urlopen(url, timeout=60)
	output = response.read().decode('utf-8')
	root = ET.fromstring(output)

	return root


# Get all the systems
root = call_API("http://restprd.corp.netapp.com/asup-rest-interface/ASUP_DATA/client_id/sustools/service_tier/*/hostname/vsff*")

systems = {}
for system_info in root.findall("./results/system"):
	hostname = system_info.find("hostname").text
	serial_no = system_info.find("sys_serial_no").text

	systems[serial_no] = hostname

print("Found {n} systems\n".format(n=len(systems)))


# Get the current date
end_date = datetime.date.today()

# Calculate the start date as 10 days before the current date
start_date = end_date - datetime.timedelta(days=10)

# Convert dates to strings in the format 'YYYY-MM-DD'
start_date_str = start_date.strftime('%Y-%m-%d')
end_date_str = end_date.strftime('%Y-%m-%d')

# Get a recent weekly ASUP for each system
asups = defaultdict(dict)
for serial_no in systems:
    api_url = ("http://restprd.corp.netapp.com/asup-rest-interface/ASUP_DATA/"
               "client_id/sustools/service_tier/*/sys_serial_no/{sn}/"
               "start_date/{start_date}/end_date/{end_date}/").format(
                   sn=serial_no, start_date=start_date_str, end_date=end_date_str)

    root = call_API(api_url)

    for asup_info in root.findall("./results/system/asups/asup"):
        if "WEEKLY_LOG" in asup_info.find("asup_subject").text:
            asups[serial_no] = asup_info.find("asup_id").text
            break


print("Found weekly ASUP for {n} systems\n".format(n=len(asups)))

# Check the IFSTAT-A section for queue drops
all_drops = {}
for serial_no in asups:
	response = urllib.request.urlopen("http://restprd.corp.netapp.com/asup-rest-interface/ASUP_DATA/client_id/sustools/service_tier/*/asup_id/{asup_id}/section_data/IFSTAT-A".format(asup_id=asups[serial_no]), timeout=60)
	output = response.read().decode('utf-8')

	output = output.split("-- interface  ")

	sys_drops = []
	for interface_stats in output:
		interface = interface_stats.split(" ", 1)[0]
		if interface[0] != 'e':
			continue

		x = interface_stats.find("Queue drops:")
		if x == -1:
			continue

		drops = interface_stats[x:x+23].split(":")[1].strip()
		if drops == "0":
			continue

		sys_drops.append((interface, drops))

	if sys_drops:
		all_drops[serial_no] = sys_drops


# Print results
print("Found {n} systems with drops".format(n=len(all_drops)))

for serial_no in all_drops:
	print("\n{h} ({sn})".format(h=systems[serial_no], sn=serial_no))
	for interface, drops in all_drops[serial_no]:
		print("  {i}: {d}".format(i=interface, d=drops))
