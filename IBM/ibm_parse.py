import re
import os
from collections import defaultdict

# Function to parse the data from a file
def parse_data_from_file(file_path):
    with open(file_path, 'r') as file:
        data = file.read()
    return parse_data(data)

# Function to parse the data string
def parse_data(data):
    pattern = re.compile(r'(\w+-\w+\d+[a-z]) \(\d+\)\s*((?:\s+[e]\d+[a-z]: \d+[km]?\s*)+)')
    port_pattern = re.compile(r'([e]\d+[a-z]): (\d+)([km]?)')

    nodes = defaultdict(dict)
    for node, ports in pattern.findall(data):
        for port, drops, scale in port_pattern.findall(ports):
            drops = int(drops)
            if scale == 'm':
                drops *= 1000000
            elif scale == 'k':
                drops *= 1000
            nodes[node][port] = drops
    return nodes

# Function to compare two sets of data
# Function to compare two sets of data
def compare_data(data_week1, data_week2):
    changes = defaultdict(dict)
    for node, ports in data_week1.items():
        for port, drops in ports.items():
            # Only consider the port if it exists in week 2 data
            if node in data_week2 and port in data_week2[node]:
                drops_week2 = data_week2[node][port]
                # Calculate the change only if it's an increase
                if drops_week2 > drops:
                    change = drops_week2 - drops
                    changes[node][port] = change
    return changes




# Assuming filenames follow a pattern like 'week1.txt' and 'week2.txt'
week1_filename = '20240506.scan.out'
week2_filename = '20240513.scan.out'

# Assuming both files are located in 'data_directory'
data_directory = '/Users/jtownsen/bin/kde-llm/netapp'

# Construct the full file paths
file_path_week1 = os.path.join(data_directory, week1_filename)
file_path_week2 = os.path.join(data_directory, week2_filename)

# Parse the data for each week
data_week1_parsed = parse_data_from_file(file_path_week1)
data_week2_parsed = parse_data_from_file(file_path_week2)

# Compare the two weeks of data
changes = compare_data(data_week1_parsed, data_week2_parsed)

# Find the node/port with the biggest change
biggest_change = None
biggest_change_value = 0
for node, ports in changes.items():
    for port, change in ports.items():
        if abs(change) > biggest_change_value:
            biggest_change = (node, port)
            biggest_change_value = abs(change)

# Output the biggest change
if biggest_change:
    change_suffix = 'drops'
    if biggest_change_value >= 1000000:
        biggest_change_value /= 1000000
        change_suffix = 'm drops'
    elif biggest_change_value >= 1000:
        biggest_change_value /= 1000
        change_suffix = 'k drops'
    print(f"The biggest change was in node {biggest_change[0]} port {biggest_change[1]} with a change of {biggest_change_value}{change_suffix}.")
else:
    print("No changes were found.")
# Optionally: Print all changes, sorted by the highest number of drops
all_changes = []
for node, ports in changes.items():
    for port, change in ports.items():
        all_changes.append((node, port, change))

# Sort by the absolute value of changes in descending order
sorted_changes = sorted(all_changes, key=lambda x: abs(x[2]), reverse=True)

# Print the sorted changes
for node, port, change in sorted_changes:
    change_suffix = 'drops'
    if abs(change) >= 1000000:
        change_display = change / 1000000
        change_suffix = 'm drops'
    elif abs(change) >= 1000:
        change_display = change / 1000
        change_suffix = 'k drops'
    else:
        change_display = change
    # Ensure the display value is positive for printing
    change_display = abs(change_display)
    print(f"Node {node} port {port} changed by {change_display}{change_suffix}.")

