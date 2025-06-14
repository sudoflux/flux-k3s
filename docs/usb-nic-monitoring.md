# USB NIC Monitoring for k3s1 and k3s2

## Background

Nodes k3s1 and k3s2 use USB 2.5GbE network adapters instead of their onboard 1GbE NICs for better performance. However, USB network interfaces can potentially be less stable than PCIe-based interfaces, making monitoring critical.

## Known Issues

1. **June 13, 2025 Incident**: k3s1 experienced a network failure where a temporary interface "tmpe2695" was renamed to "eth0", causing cluster connectivity issues. This was initially misdiagnosed as a Longhorn CSI bug.

## Monitoring Implementation

### Automated Monitoring Script

Location: `/home/josh/flux-k3s/scripts/monitor-usb-nic.sh`

The script monitors:
- USB device presence and status
- Network interface statistics and errors
- dmesg logs for USB disconnect/reconnect events
- Interface uptime and performance metrics

### Systemd Service

To enable continuous monitoring:

```bash
# Copy service file to system
sudo cp /home/josh/flux-k3s/scripts/usb-nic-monitor.service /etc/systemd/system/

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable usb-nic-monitor.service
sudo systemctl start usb-nic-monitor.service

# Check service status
sudo systemctl status usb-nic-monitor.service
```

### Manual Checks

Check USB NIC status on a node:
```bash
# List USB network devices
ssh k3s1 'lsusb | grep -i "ethernet\|network\|2.5g"'

# Check network interface details
ssh k3s1 'ip -d link show | grep -v veth'

# Check for interface errors
ssh k3s1 'ip -s -s link show | grep -A5 "RX:"'

# Recent USB events
ssh k3s1 'dmesg -T | grep -i "usb.*disconnect\|new.*speed usb device" | tail -20'
```

### Log Locations

- Monitor logs: `/var/log/usb-nic-monitor.log`
- Diagnostic snapshots: `/var/log/usb-nic-diagnostics/`
- System journal: `journalctl -u usb-nic-monitor`

## Alerting Recommendations

Consider setting up alerts for:
1. USB disconnect events in dmesg
2. Increasing RX/TX errors on network interfaces
3. Interface state changes (up/down)
4. Unusually high packet loss or retransmissions

## Mitigation Strategies

1. **systemd-networkd Protection**: Already implemented via `/etc/systemd/network/` rules to prevent CNI interface management conflicts

2. **USB Power Management**: Consider disabling USB autosuspend:
   ```bash
   echo -1 > /sys/module/usbcore/parameters/autosuspend
   ```

3. **Interface Naming**: Use predictable network interface names to avoid conflicts

4. **Redundancy Planning**: Consider adding secondary NICs or bonding for critical nodes

## Future Improvements

1. Integrate monitoring with Prometheus/Grafana for visualization
2. Set up AlertManager rules for automatic notifications
3. Consider hardware upgrades to PCIe network cards for production stability
4. Implement network interface bonding for redundancy