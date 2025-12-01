#!/bin/bash
set -e

echo "========================================"
echo "OCI Kubernetes Production Cleanup"
echo "========================================"
echo ""

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${YELLOW}⚠️  WARNING: This will destroy all resources!${NC}"
echo -e "${YELLOW}⚠️  This action cannot be undone.${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo -e "${RED}[1/2] Destroying Terraform resources...${NC}"
cd "$PROJECT_ROOT/terraform"
terraform destroy -auto-approve

echo -e "${RED}[2/2] Cleaning up generated files...${NC}"
rm -f "$PROJECT_ROOT/ansible/inventory/hosts.ini"

echo ""
echo -e "${RED}=========================================${NC}"
echo -e "${RED}✅ All resources destroyed${NC}"
echo -e "${RED}=========================================${NC}"
