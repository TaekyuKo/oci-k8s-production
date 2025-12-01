#!/bin/bash
set -e

echo "========================================"
echo "OCI Kubernetes Production Deployment"
echo "========================================"
echo ""

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 현재 디렉토리 저장
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}[1/5] Checking prerequisites...${NC}"
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform not found. Please install it."; exit 1; }
command -v ansible >/dev/null 2>&1 || { echo "❌ Ansible not found. Please install it."; exit 1; }
echo -e "${GREEN}✅ Prerequisites OK${NC}"
echo ""

echo -e "${BLUE}[2/5] Deploying infrastructure with Terraform...${NC}"
cd "$PROJECT_ROOT/terraform"
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠ terraform.tfvars not found. Please create it from terraform.tfvars.example${NC}"
    exit 1
fi

terraform init
terraform apply -auto-approve
echo -e "${GREEN}✅ Infrastructure deployed${NC}"
echo ""

echo -e "${BLUE}[3/5] Waiting for instances to be ready...${NC}"
sleep 60
echo -e "${GREEN}✅ Instances ready${NC}"
echo ""

echo -e "${BLUE}[4/5] Installing Ansible collections...${NC}"
cd "$PROJECT_ROOT/ansible"
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install community.general
echo -e "${GREEN}✅ Collections installed${NC}"
echo ""

echo -e "${BLUE}[5/5] Deploying Kubernetes and addons with Ansible...${NC}"
if [ ! -f "inventory/hosts.ini" ]; then
    echo -e "${YELLOW}⚠ Inventory not found. Terraform should have generated it.${NC}"
    exit 1
fi

ansible-playbook -i inventory/hosts.ini playbooks/00-deploy-all.yml
echo ""

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "Get master IP: ${YELLOW}terraform -chdir=terraform output -raw master_public_ip${NC}"
echo -e "Configure kubectl: ${YELLOW}scp ubuntu@<master-ip>:/home/ubuntu/.kube/config ~/.kube/config${NC}"
echo ""
