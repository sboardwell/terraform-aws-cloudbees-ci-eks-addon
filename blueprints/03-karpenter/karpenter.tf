# Karpenter Linux Nodes

resource "kubectl_manifest" "karpenter_linux_ec2_node_class" {
  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: bottlerocket
spec:
  role: "${local.node_iam_role_name}"
  amiFamily: Bottlerocket
  amiSelectorTerms:
  - alias: bottlerocket@latest
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: ${local.name}
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: ${local.name}
  metadataOptions:
    httpPutResponseHopLimit: 2
YAML
  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
  ]
}

resource "kubectl_manifest" "karpenter_linux_node_pool" {
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: linux-builds
spec:
  template:
    metadata:
      labels:
        provisioner: "karpenter"
        role: linux-builds
    spec:
      taints:
        - key: "dedicated"
          value: "linux-builds"
          effect: NoSchedule
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["arm64", "amd64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: "kubernetes.io/os"
          operator: "In"
          values: ["linux"]
        - key: "karpenter.k8s.aws/instance-cpu-manufacturer"
          operator: "In"
          values: ["amd", "intel"]
        - key: "karpenter.k8s.aws/instance-generation"
          operator: "Gt"
          values: ["5"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r", "i", "d"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: In
          values: ["4", "8", "16", "32", "48", "64"]
      nodeClassRef:
        name: bottlerocket
        group: karpenter.k8s.aws
        kind: EC2NodeClass
      kubelet:
        containerRuntime: containerd
        systemReserved:
          cpu: 100m
          memory: 100Mi
  limits:
    cpu: "1000"
    memory: 1000Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m

YAML
  depends_on = [
    module.eks,
    module.eks_blueprints_addons.karpenter,
    kubectl_manifest.karpenter_linux_ec2_node_class,
  ]
}

# Karpenter Windows Nodes 2022

resource "kubectl_manifest" "karpenter_windows_ec2_node_class" {
  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: windows2022
  annotations:
    kubernetes.io/description: "Nodes running Windows Server 2022"
spec:
  role: "${local.node_iam_role_name}"
  blockDeviceMappings:
    - deviceName: /dev/sda1
      ebs:
        volumeSize: 200Gi
        volumeType: gp3
        iops: 3000
        encrypted: true
        deleteOnTermination: true
        throughput: 700
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${local.name}
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: ${local.name}
  amiSelectorTerms:
    - alias: windows2022@latest # Windows does not support pinning
  metadataOptions:
    httpProtocolIPv6: disabled
    httpTokens: required
    httpPutResponseHopLimit: 2
  userData: |
    <powershell>
    # Restart Kubelet to ensure proper startup
    Restart-Service kubelet
    </powershell>
  tags:
    Name: "karpenter-windows-2022-node"

YAML
  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
  ]
}

resource "kubectl_manifest" "karpenter_windows_node_pool_spot" {
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: windows-builds-2022-spot
  annotations:
    kubernetes.io/description: "NodePool for Windows 2022 workloads Spot First"
spec:
  template:
    metadata:
      labels:
        type: "windows_2022"
        provisioner: "karpenter"
        windows: "2022"
        role: windows-builds
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: windows2022
      taints:
        - key: "dedicated"
          value: "windows-builds-2022"
          effect: NoSchedule

      expireAfter: 720h
      terminationGracePeriod: 30m

      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["windows"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["5"]
  
  weight: 100
  
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 1m

YAML
  depends_on = [
    module.eks,
    module.eks_blueprints_addons.karpenter,
    kubectl_manifest.karpenter_windows_ec2_node_class,
  ]
}

resource "kubectl_manifest" "karpenter_windows_node_pool_ondemand" {
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: windows-builds-2022-ondemand
  annotations:
    kubernetes.io/description: "NodePool for Windows 2022 workloads On-Demand Fallback"
spec:
  template:
    metadata:
      labels:
        type: "windows_2022"
        provisioner: "karpenter"
        windows: "2022"
        role: windows-builds
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: windows2022
      taints:
        - key: "dedicated"
          value: "windows-builds-2022"
          effect: NoSchedule

      expireAfter: 720h
      terminationGracePeriod: 30m

      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["windows"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["5"]
  
  weight: 50
  
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 1m
      
YAML
  depends_on = [
    module.eks,
    module.eks_blueprints_addons.karpenter,
    kubectl_manifest.karpenter_windows_ec2_node_class,
  ]
}
