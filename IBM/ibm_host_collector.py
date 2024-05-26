import requests
import json
import pandas as pd
from datetime import datetime
import time

relative_url = "/api/cluster/counter/tables/nic_common/rows"

def get_all_lifs(mgmt_ip, auth):
    url = f'https://{mgmt_ip}/api/network/ip/interfaces?fields=*'
    response = requests.get(url, auth=auth, verify=False)
    if response.status_code == 200:
        return response.json()['records']
    return []

# Read the list of IPs from the text file
with open('monitored_hosts.txt', 'r') as file:
    hosts = file.read().split(',')

# Assuming the first entry is the management IP for initial discovery
mgmt_ip = hosts[0].strip()
auth = ('admin', 'P@ssw0rd')  # replace with your actual username and password
lifs = get_all_lifs(mgmt_ip, auth)

# Process the LIFs and build a DataFrame
lif_data = []
for lif in lifs:
    # Check if the interface provides NFS data services
    if 'data_nfs' in lif['services']:
        lif_data.append({
            'Node': lif['location']['node']['name'],
            'Port': lif['location']['port']['name'],
            'LIF': lif['name'],
            'Management IP': mgmt_ip,
            'IP Address': lif['ip']['address']
        })




df_lifs = pd.DataFrame(lif_data)
df_lifs.to_csv('lif_details.csv', index=False)

# Main monitoring loop
while True:
    # Iterate over each host
    for base_url in hosts:
        base_url = 'https://' + base_url.strip()
        url = base_url + relative_url
        response = requests.get(url, auth=auth, verify=False)

        # Parse JSON data
        data = json.loads(response.text)

        # Create an empty list to store all the dataframes
        dfs = []

        # ... (rest of your existing code to process counters and save to CSV


        # Iterate over each record
        for record in data['records']:
            # Get the URL for more detailed information
            href = record['_links']['self']['href']
            detail_url = base_url + href
            identifier = href.split('/')[-1]
            
            # Make a request to the detail URL
            detail_response = requests.get(detail_url, auth=auth, verify=False)
            
            # Parse the detail data
            detail_data = json.loads(detail_response.text)

            # Check if the type is nic_ixl
            for prop in detail_data['properties']:
                if prop['name'] == 'type' and prop['value'] == 'nic_ixl':

                    # Iterate over the 'counters' list
                    for counter in detail_data['counters']:
                        # Check if the 'name' key is 'rss_matrix'
                        if counter['name'] == 'rss_matrix':
                            labels = counter['labels']

                            # Extract the 'values' for each counter
                            tx_frames_values = [c['values'] for c in counter['counters'] if c['label'] == 'tx_frames'][0]
                            tx_bytes_values = [c['values'] for c in counter['counters'] if c['label'] == 'tx_bytes'][0]
                            rx_frames_values = [c['values'] for c in counter['counters'] if c['label'] == 'rx_frames'][0]
                            rx_bytes_values = [c['values'] for c in counter['counters'] if c['label'] == 'rx_bytes'][0]
                            requeued_values = [c['values'] for c in counter['counters'] if c['label'] == 'requeued'][0]

                            # Concatenate the 'values' for each counter
                            values = tx_frames_values + tx_bytes_values + rx_frames_values + rx_bytes_values + requeued_values

                            # Ensure the number of 'labels' matches the number of 'values'
                            labels = labels[:len(values) // 5]

                            # Split the 'values' into their respective counters
                            tx_frames = values[0::5]
                            tx_bytes = values[1::5]
                            rx_frames = values[2::5]
                            rx_bytes = values[3::5]
                            requeued = values[4::5]

                            # Split the 'identifier' into 'node' and 'port'
                            node, port = identifier.split('%3A')

                            # Create a DataFrame for this record and append it to the list
                            record_df = pd.DataFrame({
                                'Timestamp': [datetime.now()] * len(tx_frames),
                                'Node': [node] * len(tx_frames),
                                'Port': [port] * len(tx_frames),
                                'Label': labels,
                                'TX Frames': tx_frames,
                                'TX Bytes': tx_bytes,
                                'RX Frames': rx_frames,
                                'RX Bytes': rx_bytes,
                                'Requeued': requeued
                            })
                            dfs.append(record_df)

        # Check if the 'dfs' list is empty
        if dfs:
            # Concatenate all the dataframes in the list
            df = pd.concat(dfs, ignore_index=True)

            # Check if the CSV file already exists
            try:
                existing_df = pd.read_csv('output.csv')

                # If it does, append the new data to it
                df = pd.concat([existing_df, df], ignore_index=True)
            except FileNotFoundError:
                # If it doesn't, we'll create it below
                pass

            # Save the DataFrame to a CSV file
            df.to_csv('output.csv', index=False)
        else:
            print("No data to save.")

    # Sleep for 5 minutes
    time.sleep(300)
