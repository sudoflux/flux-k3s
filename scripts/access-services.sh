#!/bin/bash
# Temporary script to access services while Gateway is being fixed

echo "=== Service Access Script ==="
echo ""
echo "Services are temporarily accessible via port-forward while we fix the Gateway issue."
echo ""
echo "Available services:"
echo "1. Prometheus - http://localhost:9090"
echo "2. Grafana - http://localhost:3000"
echo "3. Longhorn - http://localhost:8080"
echo "4. Authentik - http://localhost:9000"
echo ""
echo "Which service would you like to access? (1-4): "
read -r choice

case $choice in
    1)
        echo "Starting Prometheus port-forward..."
        echo "Access at: http://localhost:9090"
        kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
        ;;
    2)
        echo "Starting Grafana port-forward..."
        echo "Access at: http://localhost:3000"
        echo "Default credentials: admin / (check secret)"
        kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
        ;;
    3)
        echo "Starting Longhorn port-forward..."
        echo "Access at: http://localhost:8080"
        kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
        ;;
    4)
        echo "Starting Authentik port-forward..."
        echo "Access at: http://localhost:9000"
        kubectl port-forward -n authentik svc/authentik-server 9000:80
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac