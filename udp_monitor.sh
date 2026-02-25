#!/bin/bash

# Define the network interface and UDP port
INTERFACE=wlan0
PORT=51820

# Create a temporary file to store packet counts
TEMP_FILE=$(mktemp)

# Function to clean up on exit
cleanup() {
    rm -f "$TEMP_FILE"
}

trap cleanup EXIT

# Run tcpdump in the background to capture UDP packets
tcpdump -i "$INTERFACE" udp port "$PORT" -w - | while read -r line; do
    # Extract the source IP address from the packet
    SOURCE_IP=$(echo "$line" | grep -oP 'src \K[0-9.]+')
    
    # Increment the count for this source IP in the temporary file
    if [ -f "$TEMP_FILE" ]; then
        awk -v ip="$SOURCE_IP" '$1 == ip { $2 += 1; print; next } END { print ip, 1 }' "$TEMP_FILE" > temp && mv temp "$TEMP_FILE"
    else
        echo "$SOURCE_IP 1" >> "$TEMP_FILE"
    fi
done &

# Capture the PID of the tcpdump process
TCPDUMP_PID=$!

# Wait for 60 seconds to capture packets
sleep 60

# Stop the tcpdump process
kill -9 "$TCPDUMP_PID"

# Print the packet counts from the temporary file
cat "$TEMP_FILE"
