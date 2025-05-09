# Linux Nodes

resource "kubectl_manifest" "karpenter_linux_ec2_node_class" {
  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: bottlerocket
  annotations:
    kubernetes.io/description: "Nodes running Linux Bottlerocket"
spec:
  role: "${local.node_iam_role_name}"
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeType: gp3
        volumeSize: 4Gi
        deleteOnTermination: true
    # Bottlerocket data volume
    - deviceName: /dev/xvdb
      ebs:
        volumeSize: 200Gi
        volumeType: gp3
        iops: 3000
        encrypted: true
        deleteOnTermination: true
        throughput: 700
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
    module.eks_blueprints_addons.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_linux_node_pool" {
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: linux-builds-spot
  annotations:
    kubernetes.io/description: "Nodes running Linux Bottlerocket"
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

      # Recycle nodes after $expireAfter so they have latest updates
      # Give the pods $terminationGracePeriod time to complete after the node is about to be recycled
      expireAfter: 720h
      terminationGracePeriod: 48h

      requirements:
        - key: "kubernetes.io/os"
          operator: "In"
          values: ["linux"]
        # Karpenter supposed to use Spot instances first (because they are cheaper), switching to On-demand only if there are no Spot instances available (fallback)
        # You could have more granular control using weights and priorities
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: kubernetes.io/arch
          operator: In
          values: ["arm64", "amd64"]
        - key: "karpenter.k8s.aws/instance-cpu-manufacturer"
          operator: "In"
          values: ["amd", "intel"]
        - key: "karpenter.k8s.aws/instance-generation"
          operator: "Gt"
          values: ["5"]
      nodeClassRef:
        name: bottlerocket
        group: karpenter.k8s.aws
        kind: EC2NodeClass

  # Priority given to the NodePool when the scheduler considers which NodePool
  # to select. Higher weights indicate higher priority when comparing NodePools.
  # Specifying no weight is equivalent to specifying a weight of 0.
  weight: 100

  limits:
    cpu: 500
    memory: 1000Gi

  # Disruption section which describes the ways in which Karpenter can disrupt and replace Nodes
  # Configuration in this section constrains how aggressive Karpenter can be with performing operations
  # like rolling Nodes due to them hitting their maximum lifetime (expiry) or scaling down nodes to reduce cluster cost
  disruption:
    # Describes which types of Nodes Karpenter should consider for consolidation
    # If using 'WhenEmptyOrUnderutilized', Karpenter will consider all nodes for consolidation and attempt to remove or replace Nodes when it discovers that the Node is empty or underutilized and could be changed to reduce cost
    # If using `WhenEmpty`, Karpenter will only consider nodes for consolidation that contain no workload pods
    consolidationPolicy: WhenEmpty
    consolidateAfter: 1m
    # Omitting the field Budgets will cause the field to be defaulted to one Budget with Nodes: 10%.
    budgets:
    - nodes: 100%
      reasons:
      - "Empty"
      - "Drifted"

YAML
  depends_on = [
    kubectl_manifest.karpenter_linux_ec2_node_class
  ]
}

# Windows Nodes 2022

resource "kubectl_manifest" "karpenter_windows_2022_ec2_node_class" {
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
        volumeSize: 300Gi
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
  tags:
    Name: "karpenter-windows-2022-node"

YAML
  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_windows_2022_node_pool" {
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: windows-builds-2022
  annotations:
    kubernetes.io/description: "Nodes running Windows Server 2022, spot and on-demand combined"
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
      terminationGracePeriod: 48h

      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["windows"]
        # Karpenter supposed to use Spot instances first (because they are cheaper), switching to On-demand only if there are no Spot instances available
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["5"]

  weight: 100

  limits:
    cpu: 500
    memory: 1000Gi

  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 5m
    budgets:
    - nodes: 100%
      reasons:
      - "Empty"

YAML
  depends_on = [
    kubectl_manifest.karpenter_windows_2022_ec2_node_class
  ]
}

# Karpenter Windows Nodes 2019

resource "kubectl_manifest" "karpenter_windows_2019_ec2_node_class" {
  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: windows2019
  annotations:
    kubernetes.io/description: "Nodes running Windows Server 2019"
spec:
  role: "${local.node_iam_role_name}"
  blockDeviceMappings:
    - deviceName: /dev/sda1
      ebs:
        volumeSize: 300Gi
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
    - alias: windows2019@latest # Windows does not support pinning
  metadataOptions:
    httpProtocolIPv6: disabled
    httpTokens: required
    httpPutResponseHopLimit: 2
  tags:
    Name: "karpenter-windows-2019-node"

YAML
  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_windows_2019_node_pool" {
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: windows-builds-2019
  annotations:
    kubernetes.io/description: "Nodes running Windows Server 2019, spot and on-demand combined"
spec:
  template:
    metadata:
      labels:
        type: "windows_2019"
        provisioner: "karpenter"
        windows: "2019"
        role: windows-builds
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: windows2019
      taints:
        - key: "dedicated"
          value: "windows-builds-2019"
          effect: NoSchedule

      expireAfter: 720h
      terminationGracePeriod: 48h

      requirements:
        - key: kubernetes.io/os
          operator: In
          values: ["windows"]
        # Karpenter supposed to use Spot instances first, switching to On-demand only if there are no Spot instances available
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["5"]

  weight: 100

  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 5m
    budgets:
    - nodes: 100%
      reasons:
      - "Empty"

YAML
  depends_on = [
    kubectl_manifest.karpenter_windows_2019_ec2_node_class
  ]
}
