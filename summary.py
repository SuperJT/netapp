import sys
import re

# Function to convert the error counts to integers
def convert_to_number(error_str):
    if 'k' in error_str:
        return int(float(error_str.replace('k', '')) * 1000)
    elif 'm' in error_str:
        return int(float(error_str.replace('m', '')) * 1000000)
    else:
        return int(error_str)

# Parse the data from standard input
node_errors = {}
current_node = None
for line in sys.stdin:
    line = line.strip()
    if line.startswith('vsff-'):
        current_node = line.split()[0]
        node_errors[current_node] = 0
    elif ':' in line:
        port, error_count = line.split(':')
        node_errors[current_node] += convert_to_number(error_count.strip())

# Sort the nodes by total errors in descending order
sorted_nodes = sorted(node_errors.items(), key=lambda item: item[1], reverse=True)

# Calculate the top 25%
top_25_percent_index = int(len(sorted_nodes) * 0.25)
top_25_percent_nodes = sorted_nodes[:top_25_percent_index]

# Print the top 25% of nodes with the most errors
print(f"Top 25% of nodes with the most errors (Total nodes: {len(sorted_nodes)}):")
for node, total_errors in top_25_percent_nodes:
    print(f"{node}: {total_errors} errors")

# If you want to see the full sorted list, uncomment the following lines:
# print("\nFull sorted list of nodes by errors:")
# for node, total_errors in sorted_nodes:
#     print(f"{node}: {total_errors} errors")

