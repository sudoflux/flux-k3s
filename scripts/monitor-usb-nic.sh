#!/bin/bash
# USB NIC Local Monitoring Script
# This script monitors USB network interface stability on the local node

set -euo pipefail

# Configuration
LOG_FILE="/var/log/usb-nic-monitor.log"
DIAG_DIR="/var/log/usb-nic-diagnostics"
CHECK_INTERVAL=300  # 5 minutes

# Create directories if needed
mkdir -p "$DIAG_DIR"
touch "$LOG_FILE"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Function to collect diagnostics
collect_diagnostics() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local diag_file="$DIAG_DIR/diag_${HOSTNAME}_${timestamp}.txt"
    
    {
        echo "=== USB NIC Diagnostics for $HOSTNAME at $(date) ==="
        echo
        echo "=== USB Devices ==="
        lsusb | grep -i "ethernet\|network\|2.5g\|realtek\|asix" || echo "No USB network devices found"
        echo
        echo "=== Network Interfaces ==="
        ip -d link show | grep -v veth
        echo
        echo "=== Interface Statistics ==="
        ip -s -s link show | grep -A5 -B1 "^[0-9]" | grep -v veth
        echo
        echo "=== Recent USB Events ==="
        dmesg -T | grep -i "usb.*disconnect\|new.*speed usb device" | tail -20
        echo
        echo "=== Network Errors ==="
        ip -s link show | grep -A5 "RX:" | grep -E "errors|dropped|overrun"
    } > "$diag_file" 2>&1
    
    log "Diagnostics saved to $diag_file"
}

# Function to check USB NIC status
check_usb_nic() {
    log "Checking USB NIC status on $HOSTNAME"
    
    # Check for USB network devices
    local usb_count=$(lsusb | grep -ci "ethernet\|network\|2.5g\|realtek\|asix" || echo 0)
    if [[ $usb_count -eq 0 ]]; then
        log "ERROR: No USB network devices detected!"
        collect_diagnostics
        return 1
    fi
    
    # Check for physical network interfaces
    local nic_count=$(ip link show | grep -E "^[0-9]+: (eth|enx|enp)" | grep -cv "veth" || echo 0)
    if [[ $nic_count -eq 0 ]]; then
        log "ERROR: No physical network interfaces found!"
        collect_diagnostics
        return 1
    fi
    
    # Check for link state
    local down_links=$(ip link show | grep -E "^[0-9]+: (eth|enx|enp)" | grep -v veth | grep "state DOWN" || true)
    if [[ -n "$down_links" ]]; then
        log "WARNING: Network interface(s) are DOWN:"
        echo "$down_links" >> "$LOG_FILE"
        collect_diagnostics
    fi
    
    # Check for recent USB disconnects
    local recent_disconnects=$(dmesg -T | grep -i "usb.*disconnect" | grep -E "$(date '+%Y-%m-%d')" | tail -5 || true)
    if [[ -n "$recent_disconnects" ]]; then
        log "WARNING: Recent USB disconnects detected today:"
        echo "$recent_disconnects" >> "$LOG_FILE"
        collect_diagnostics
    fi
    
    # Check error counters
    local error_count=$(ip -s link show | grep -A5 "RX:" | grep errors | awk '{print $3}' | paste -sd+ | bc 2>/dev/null || echo 0)
    if [[ $error_count -gt 0 ]]; then
        log "WARNING: Network interface errors detected: $error_count total errors"
    fi
    
    log "USB NIC check complete for $HOSTNAME"
}

# Main loop
log "Starting USB NIC monitoring for $HOSTNAME"

# Initial check
check_usb_nic

# Continuous monitoring
while true; do
    sleep "$CHECK_INTERVAL"
    check_usb_nic
done