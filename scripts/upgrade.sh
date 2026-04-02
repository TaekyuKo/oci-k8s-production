#!/bin/bash
set -e

echo "========================================"
echo "OCI Kubernetes Cluster Upgrade"
echo "========================================"
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}[1/3] Checking prerequisites...${NC}"
command -v ansible >/dev/null 2>&1 || { echo "❌ Ansible not found. Please install it."; exit 1; }
echo -e "${GREEN}✅ Prerequisites OK${NC}"
echo ""

echo -e "${BLUE}[2/3] Verifying inventory...${NC}"
cd "$PROJECT_ROOT/ansible"
if [ ! -f "inventory/hosts.ini" ]; then
    echo -e "${YELLOW}⚠ Inventory not found. Please run deploy.sh first.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Inventory found${NC}"
echo ""

echo -e "${YELLOW}⚠️  This will upgrade Kubernetes and all addons.${NC}"
echo -e "${YELLOW}⚠️  Workloads may be temporarily rescheduled.${NC}"
echo ""
read -p "Continue with upgrade? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo -e "${BLUE}[3/3] Running upgrade playbook...${NC}"
ansible-playbook -i inventory/hosts.ini playbooks/upgrade.yml
echo ""

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ Upgrade Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "Verify cluster: ${YELLOW}kubectl get nodes${NC}"
echo -e "Check versions: ${YELLOW}kubectl version --short${NC}"
echo -e "List addons: ${YELLOW}helm list -A${NC}"
echo ""
