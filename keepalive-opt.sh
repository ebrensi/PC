#!/bin/bash

# Configuration
INTERFACE="wg-home"
PEER_ID="srov/ElxjM0BPfQHhCFN2sb3UEkwIhFQGSS55P/HIEA="
PEER_IP="fd001" # The internal WireGuard IP of the peer to ping

# Initial State
CURRENT_TEST=25    # Start at the standard 25s
LAST_GOOD=25
MAX_KNOWN_BAD=3600 # 1 hour
MODE="EXPAND"      # Start by doubling

echo "Starting discovery for Peer: ${PEER_ID:0:8}..."

while true; do
    echo "------------------------------------------------"
    echo "Testing Interval: ${CURRENT_TEST}s (Mode: $MODE)"
    
    # 1. Force a fresh handshake to ensure a clean slate
    # We do this by setting a very short keepalive temporarily
    wg set $INTERFACE peer "$PEER_ID" persistent-keepalive 1
    sleep 2
    ping -c 1 -W 1 $PEER_IP > /dev/null
    
    # Capture the "baseline" handshake after the fresh ping
    START_TS=$(wg show $INTERFACE latest-handshakes | grep "$PEER_ID" | awk '{print $2}')
    
    # 2. Wait for the test duration
    # Turn off keepalive for the duration of the "wait" to see if NAT expires
    wg set $INTERFACE peer "$PEER_ID" persistent-keepalive 0
    echo "Waiting $CURRENT_TEST seconds to see if NAT hole stays open..."
    sleep $CURRENT_TEST
    
    # 3. Probe the connection
    ping -c 1 -W 2 $PEER_IP > /dev/null
    END_TS=$(wg show $INTERFACE latest-handshakes | grep "$PEER_ID" | awk '{print $2}')

    # 4. Analyze Results
    if [ "$START_TS" -eq "$END_TS" ]; then
        echo "SUCCESS: NAT hole stayed open."
        LAST_GOOD=$CURRENT_TEST
        
        if [ "$MODE" == "EXPAND" ]; then
            CURRENT_TEST=$((CURRENT_TEST * 2))
            if [ $CURRENT_TEST -ge $MAX_KNOWN_BAD ]; then
                CURRENT_TEST=$MAX_KNOWN_BAD
                MODE="BISECT"
            fi
        else
            # Binary Search: Move up
            LOWER_BOUND=$CURRENT_TEST
            CURRENT_TEST=$(( (LOWER_BOUND + UPPER_BOUND) / 2 ))
        fi
    else
        echo "FAIL: Handshake updated. NAT hole closed."
        UPPER_BOUND=$CURRENT_TEST
        MODE="BISECT"
        # Binary Search: Move down
        CURRENT_TEST=$(( (LAST_GOOD + UPPER_BOUND) / 2 ))
    fi

    echo "Current Best PersistentKeepalive: ${LAST_GOOD}s"
    
    # Exit condition: If we are within 5 seconds of precision
    if [ "$MODE" == "BISECT" ] && [ $((UPPER_BOUND - LAST_GOOD)) -lt 5 ]; then
        echo "================================================"
        echo "OPTIMUM FOUND: Set PersistentKeepalive = $LAST_GOOD"
        echo "================================================"
        exit 0
    fi
done
