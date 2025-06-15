#!/bin/bash
# Script to clean Longhorn directories on all nodes

NODES="k3s1 k3s2 k3s3"

for NODE in $NODES; do
    echo "Cleaning Longhorn directories on $NODE..."
    ssh $NODE "sudo rm -rf /var/lib/rancher/k3s/agent/kubelet/plugins/driver.longhorn.io"
    ssh $NODE "sudo rm -rf /var/lib/rancher/k3s/agent/kubelet/plugins_registry/driver.longhorn.io"
    ssh $NODE "sudo rm -rf /var/lib/longhorn/*"
    echo "Cleaned $NODE"
done

echo "All nodes cleaned"