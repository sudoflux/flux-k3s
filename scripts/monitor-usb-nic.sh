#!/bin/bash
# USB NIC Monitoring Script for k3s1 and k3s2
# This script monitors USB network interface stability

set -euo pipefail

# Configuration
LOG_FILE="/var/log/usb-nic-monitor.log"
NODES=("k3s1" "k3s2")
CHECK_INTERVAL=300  # 5 minutes

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Function to check USB NIC on a node
check_usb_nic() {
    local node=$1
    log "Checking USB NIC on $node"
    
    # Get USB network devices
    ssh "$node" 'lsusb | grep -i "ethernet\|network\|2.5g\|realtek\|asix"' 2>/dev/null || {
        log "ERROR: Could not query USB devices on $node"
        return 1
    }
    
    # Check network interface status
    local nic_info=$(ssh "$node" 'ip link show | grep -E "^[0-9]+: (eth|enx|enp)" | grep -v "veth"' 2>/dev/null)
    if [[ -z "$nic_info" ]]; then
        log "WARNING: No physical network interfaces found on $node"
        return 1
    fi
    
    # Check for link errors
    local errors=$(ssh "$node" 'ip -s link show | grep -A5 "RX:" | grep errors' 2>/dev/null)
    if [[ -n "$errors" ]]; then
        log "Network errors detected on $node: $errors"
    fi
    
    # Check dmesg for USB disconnect/reconnect events
    local usb_events=$(ssh "$node" 'dmesg -T | grep -i "usb.*disconnect\|new.*speed usb device" | tail -5' 2>/dev/null)
    if [[ -n "$usb_events" ]]; then
        log "Recent USB events on $node:"
        echo "$usb_events" >> "$LOG_FILE"
    fi
    
    # Check interface uptime
    local uptime=$(ssh "$node" 'cat /proc/net/dev | grep -E "(eth|enx|enp)" | grep -v veth' 2>/dev/null)
    log "Interface statistics for $node:"
    echo "$uptime" >> "$LOG_FILE"
    
    return 0
}

# Function to collect detailed diagnostics
collect_diagnostics() {
    local node=$1
    local diag_dir="/var/log/usb-nic-diagnostics"
    
    log "Collecting detailed diagnostics for $node"
    
    ssh "$node" "mkdir -p $diag_dir"
    
    # Collect various diagnostic information
    ssh "$node" "
        echo '=== USB Devices ===' > $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt
        lsusb -v 2>/dev/null | grep -A20 -B5 -i 'ethernet\|network' >> $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt
        echo -e '\n=== Network Interfaces ===' >> $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt
        ip -d link show >> $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt
        echo -e '\n=== Interface Statistics ===' >> $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt
        ip -s -s link show >> $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt
        echo -e '\n=== ethtool Info ===' >> $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt
        for iface in \$(ip link show | grep -E '^[0-9]+: (eth|enx|enp)' | cut -d: -f2 | tr -d ' ' | grep -v veth); do
            echo \"Interface: \$iface\" >> $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt
            ethtool \$iface 2>/dev/null >> $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt || true
            ethtool -S \$iface 2>/dev/null >> $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt || true
        done
        echo -e '\n=== Recent dmesg USB/Network Events ===' >> $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt
        dmesg -T | grep -i 'usb\|eth\|enx\|network' | tail -100 >> $diag_dir/${node}-usb-diag-\$(date +%Y%m%d-%H%M%S).txt
    "
}

# Main monitoring loop
main() {
    log "Starting USB NIC monitoring for nodes: ${NODES[*]}"
    
    # Initial diagnostic collection
    for node in "${NODES[@]}"; do
        collect_diagnostics "$node"
    done
    
    # Continuous monitoring
    while true; do
        for node in "${NODES[@]}"; do
            if ! check_usb_nic "$node"; then
                log "ERROR: USB NIC check failed for $node"
                collect_diagnostics "$node"
            fi
        done
        
        log "Sleeping for $CHECK_INTERVAL seconds..."
        sleep "$CHECK_INTERVAL"
    done
}

# Run main function
main