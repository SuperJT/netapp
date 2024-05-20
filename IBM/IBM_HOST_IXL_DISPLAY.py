import requests
import json
import pandas as pd
import numpy as np
import argparse
import sys
from datetime import datetime

# Create the parser
parser = argparse.ArgumentParser(description='aid in identifying a hung netapp nic queue.')

# Add the arguments
parser.add_argument('-node', metavar='node', type=str, help='the node to filter by')
parser.add_argument('-port', metavar='port', type=str, help='the port to filter by')
parser.add_argument('-queue', metavar='queue', type=str, help='the queue to filter by')
parser.add_argument('-report', action='store_true', help='report queues that have stopped increasing')

# Parse the arguments
args = parser.parse_args()

# Load the CSV file
df = pd.read_csv('output.csv')


# Convert 'Timestamp' column to datetime
df['Timestamp'] = pd.to_datetime(df['Timestamp'])

# Sort the DataFrame by 'Node', 'Port', 'Label', and 'Timestamp'
df = df.sort_values(['Node', 'Port', 'Label', 'Timestamp'])
# ...

# Calculate the difference for each counter for each queue host
df['RX Bytes Diff'] = df.groupby(['Node', 'Port', 'Label'])['RX Bytes'].diff().fillna(0).astype(int)

# Function to count consecutive zeros in the 'RX Bytes Diff' column
def count_consecutive_zeros(series):
    count = 0
    result = []
    for value in series:
        if value == 0:
            count += 1
        else:
            count = 0  # Reset the count if there is activity
        result.append(count)
    return pd.Series(result, index=series.index)

# Apply the function to count consecutive zeros
df['Consecutive Zeros'] = df.groupby(['Node', 'Port', 'Label'])['RX Bytes Diff'].transform(count_consecutive_zeros)

# Filter out rows where 'RX Bytes' is 0
df = df[df['RX Bytes'] != 0]

# Identify hung queues based on the most recent consecutive zeros
# Get the last entry for each queue of each host
last_entries = df.groupby(['Node', 'Port', 'Label']).tail(1)

# Filter to find queues where the most recent 'Consecutive Zeros' is 3 or more
hang_queues = last_entries[last_entries['Consecutive Zeros'] >= 3]

# ...

# If no arguments were provided, execute the '-report' function
if len(sys.argv) == 1:
    if hang_queues.empty:
        print("No active queues have stopped increasing.")
    else:
        print("The following active queues have stopped increasing:")
        print(hang_queues)
else:
    # Print the queues that have stopped increasing if the '-report' flag is used
    if args.report:
        if hang_queues.empty:
            print("No active queues have stopped increasing.")
        else:
            print("The following active queues have stopped increasing:")
            print(hang_queues)

    # Filter the DataFrame based on the options provided
    if args.node:
        df = df[df['Node'] == args.node]
    if args.port:
        df = df[df['Port'] == args.port]
    if args.queue:
        df = df[df['Label'] == 'queue_' + args.queue]

    if args.node or args.port or args.queue:
        print(df)
