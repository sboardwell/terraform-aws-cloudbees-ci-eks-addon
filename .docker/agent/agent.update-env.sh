#!/bin/bash

echo "Building ENV Block with latest versions..."
echo "======================================="

TF_VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest | jq -r '.tag_name' | sed 's/v//')
KUBECTL_VERSION=$(curl -s https://api.github.com/repos/kubernetes/kubernetes/releases/latest | jq -r '.tag_name' | sed 's/v//')
VELERO_VERSION=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | jq -r '.tag_name' | sed 's/v//')
EKSCTL_VERSION=$(curl -s https://api.github.com/repos/weaveworks/eksctl/releases/latest | jq -r '.tag_name' | sed 's/v//')


echo ""
echo "ENV block for Dockerfile:"
echo "ENV TF_VERSION=$TF_VERSION \\"
echo "    KUBECTL_VERSION=$KUBECTL_VERSION \\"
echo "    VELERO_VERSION=$VELERO_VERSION \\"
echo "    EKSCTL_VERSION=$EKSCTL_VERSION \\"
echo "    USER=bp-agent \\"
echo "    ARCH=amd64"
