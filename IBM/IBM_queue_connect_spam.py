from scapy.all import *
from scapy.layers.inet import IP, TCP
import struct
import random
import argparse

def perform_rpc_null_call(target_ip, target_port=111):
    # Generate a random source port
    sport = random.randint(1024, 65535)

    # Create the IP layer
    ip = IP(dst=target_ip)

    # Create the SYN packet
    syn = TCP(sport=sport, dport=target_port, flags='S', seq=1000)

    # Send the SYN packet and wait for a SYN-ACK response
    syn_ack = sr1(ip/syn, timeout=2)

    # Check if we received a SYN-ACK
    if syn_ack and syn_ack.haslayer(TCP) and syn_ack.getlayer(TCP).flags & 0x12:  # SYN-ACK flags
        # Create the ACK packet to complete the handshake
        ack = TCP(sport=sport, dport=target_port, flags='A', seq=syn_ack.ack, ack=syn_ack.seq + 1)
        send(ip/ack)
        
        # Define the RPC call parameters
        xid = random.randint(0, 0xFFFFFFFF)  # Random Transaction ID
        message_type = 0  # Call (0)
        rpc_version = 2  # RPC Version
        program_number = 100000  # PORTMAP program number
        program_version = 2  # PORTMAP program version
        procedure_number = 0  # NULL procedure

        # ... (previous code)

        # Create the RPC packet
        rpc_packet = ip/TCP(sport=sport, dport=target_port, flags='PA', seq=syn_ack.ack, ack=syn_ack.seq + 1)

        # ... (previous code)

        # Create the RPC packet
        rpc_packet = ip/TCP(sport=sport, dport=target_port, flags='PA', seq=syn_ack.ack, ack=syn_ack.seq + 1)

        # Construct the RPC call payload with the fragment header
        is_last_fragment = 0x80000000  # High bit set to 1, indicating the last fragment
        fragment_length = 28  # Length of the RPC call, excluding the fragment header
        rpc_call = struct.pack('!I', is_last_fragment | fragment_length)
        rpc_call += struct.pack('!I', xid)  # XID
        rpc_call += struct.pack('!I', 0)  # Message Type: Call (0)
        rpc_call += struct.pack('!I', 2)  # RPC Version: 2
        rpc_call += struct.pack('!I', 100000)  # Program Number: PORTMAP
        rpc_call += struct.pack('!I', 2)  # Program Version: 2
        rpc_call += struct.pack('!I', 0)  # Procedure: NULL
        rpc_call += struct.pack('!I', 0)  # Credentials Flavor: AUTH_NULL
        rpc_call += struct.pack('!I', 0)  # Credentials Length: 0
        rpc_call += struct.pack('!I', 0)  # Verifier Flavor: AUTH_NULL
        rpc_call += struct.pack('!I', 0)  # Verifier Length: 0

        # Attach the RPC call payload to the packet
        rpc_packet /= Raw(load=rpc_call)

        # Send the RPC call and wait for a response
        response = sr1(rpc_packet, timeout=2)  # Wait for a response for 2 seconds

        # ... (rest of the code)


        # Check if a response was received
        if response:
            print(f"Received a response from {target_ip}:")
            response.show()
        else:
            print(f"No response received from {target_ip}.")
    else:
        print(f"No SYN-ACK received from {target_ip}. Exiting.")

# Create the parser
parser = argparse.ArgumentParser(description='Perform RPC Null calls to test TCP communication.')
parser.add_argument('ips', metavar='IP', type=str, nargs='+', help='IP addresses to test')

# Parse the arguments
args = parser.parse_args()

# Perform RPC Null calls on the provided IP addresses
for ip_address in args.ips:
    perform_rpc_null_call(ip_address)
