import time
import socket
import argparse
import random

# Create the parser
parser = argparse.ArgumentParser(description='Test connectivity to a target IP on port 111.')
parser.add_argument('--target-ip', type=str, required=True, help='the target IP to connect to')

# Parse the arguments
args = parser.parse_args()

target_ip = args.target_ip
target_port = 111  # Hardcoded to use TCP/111

success = 0
fail = 0
attempts = 0

# Generate a list of 128 unique random source ports between 60000 and 64000
random_ports = random.sample(range(60000, 64001), 128)

while attempts < 128 and len(random_ports) > 0:
    local_port = random_ports.pop()  # Get a random port and remove it from the list
    attempts += 1  # Increment the number of attempts
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(("0.0.0.0", local_port))
            s.settimeout(2)
            s.connect((target_ip, target_port))
        success += 1

    except socket.timeout:
        print(f"Timeout error: Could not connect to {target_ip} on port {target_port} from source port {local_port}")
        fail += 1
    except OSError as e:
        if e.errno == 98:  # Address already in use
            print(f"OSError: Port {local_port} is already in use. Skipping.")
        else:
            print(f"OSError: An operating system error occurred while trying to connect to {target_ip} on port {target_port} from source port {local_port}: {e}")
            fail += 1
    except Exception as e:
        print(f"Encountered an unexpected error while trying to connect to {target_ip} on port {target_port} from source port {local_port}: {type(e).__name__} - {e}")
        fail += 1

    time.sleep(0.1)

if success+fail == 0:
    print("All attempts encountered unexpected errors")
else:
    print(f"TCP socket testing..: {success}/{success+fail} ({success/(success+fail):.1%})")
