#!/bin/bash
# Emergency Authentik Admin Password Reset Script
# CRITICAL: Run this to secure Prometheus which is exposed without authentication

set -e

echo "=== Authentik Admin Password Reset Tool ==="
echo "This script will help you reset the Authentik admin password"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check connection to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

# Function to get pod name
get_pod_name() {
    local component=$1
    kubectl get pods -n authentik -l "app.kubernetes.io/component=${component}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Main menu
echo "Choose password reset method:"
echo "1. Generate recovery link (RECOMMENDED - Fastest)"
echo "2. Reset via Django shell"
echo "3. Direct database access"
echo "4. Check Authentik status"
echo ""
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo -e "\n${YELLOW}Generating recovery link...${NC}"
        SERVER_POD=$(get_pod_name "server")
        
        if [ -z "$SERVER_POD" ]; then
            echo -e "${RED}Error: Cannot find Authentik server pod${NC}"
            exit 1
        fi
        
        echo "Found server pod: $SERVER_POD"
        echo -e "\n${GREEN}Recovery link:${NC}"
        kubectl exec -it -n authentik "$SERVER_POD" -- ak create_recovery_link akadmin 2>/dev/null || {
            echo -e "${RED}Failed to generate recovery link. Trying alternative method...${NC}"
            kubectl exec -n authentik "$SERVER_POD" -- /bin/bash -c "ak create_recovery_link akadmin"
        }
        
        echo -e "\n${YELLOW}Instructions:${NC}"
        echo "1. Copy the recovery link above"
        echo "2. Open it in your web browser"
        echo "3. Set a new password for akadmin"
        echo "4. Login and secure Prometheus immediately!"
        ;;
        
    2)
        echo -e "\n${YELLOW}Resetting password via Django shell...${NC}"
        WORKER_POD=$(get_pod_name "worker")
        
        if [ -z "$WORKER_POD" ]; then
            echo -e "${RED}Error: Cannot find Authentik worker pod${NC}"
            exit 1
        fi
        
        echo "Found worker pod: $WORKER_POD"
        read -s -p "Enter new password for akadmin: " NEW_PASSWORD
        echo ""
        
        # Create Python script
        PYTHON_SCRIPT="
from authentik.core.models import User
try:
    akadmin = User.objects.get(username='akadmin')
    akadmin.set_password('${NEW_PASSWORD}')
    akadmin.save()
    print('Password reset successfully!')
except Exception as e:
    print(f'Error: {e}')
"
        
        echo -e "\n${YELLOW}Executing password reset...${NC}"
        echo "$PYTHON_SCRIPT" | kubectl exec -i -n authentik "$WORKER_POD" -- ak shell
        
        echo -e "\n${GREEN}Password reset complete!${NC}"
        echo "You can now login with username: akadmin"
        ;;
        
    3)
        echo -e "\n${YELLOW}Accessing PostgreSQL directly...${NC}"
        echo -e "${YELLOW}PostgreSQL Password:${NC} TOtREQVNTNc4149HvuM6GQxrNK7s7ftv"
        echo ""
        echo "You will be connected to the PostgreSQL shell."
        echo "Run these commands to check users:"
        echo -e "${GREEN}SELECT pk, username, email, is_active, is_superuser FROM authentik_core_user WHERE username = 'akadmin';${NC}"
        echo ""
        
        kubectl exec -it -n authentik authentik-postgresql-0 -- bash -c "PGPASSWORD=TOtREQVNTNc4149HvuM6GQxrNK7s7ftv psql -U postgres -d authentik"
        ;;
        
    4)
        echo -e "\n${YELLOW}Checking Authentik status...${NC}"
        echo -e "\n${GREEN}Pods:${NC}"
        kubectl get pods -n authentik
        
        echo -e "\n${GREEN}Services:${NC}"
        kubectl get svc -n authentik
        
        echo -e "\n${GREEN}Recent events:${NC}"
        kubectl get events -n authentik --sort-by='.lastTimestamp' | tail -10
        
        echo -e "\n${GREEN}Server logs (last 20 lines):${NC}"
        SERVER_POD=$(get_pod_name "server")
        if [ -n "$SERVER_POD" ]; then
            kubectl logs -n authentik "$SERVER_POD" --tail=20
        fi
        ;;
        
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "\n${YELLOW}=== IMPORTANT NEXT STEPS ===${NC}"
echo "1. Login to Authentik at https://authentik.fletcherlabs.net"
echo "2. Verify/Create OAuth2 application for Prometheus"
echo "3. Ensure OAuth2-Proxy is properly configured"
echo "4. Test Prometheus access is now secured"
echo -e "${RED}5. CRITICAL: Prometheus is currently exposed without authentication!${NC}"