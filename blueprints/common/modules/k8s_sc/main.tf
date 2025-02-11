locals {
  create_efs_storage_class = alltrue([var.create_efs_storage_class, var.efs_id != null])
}

resource "kubernetes_annotations" "gp2" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  # This is true because the resources was already created by the ebs-csi-driver addon
  force      = "true"

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
}

resource "kubernetes_storage_class_v1" "gp3_a" {
  metadata {
    name = "gp3-a"

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  # Issue #195
  allowed_topologies {
    match_label_expressions {
      key    = "topology.ebs.csi.aws.com/zone"
      values = ["${var.aws_region}a"]
    }
  }

  parameters = {
    encrypted = "true"
    fsType    = "ext4"
    type      = "gp3"
  }

}

resource "kubernetes_storage_class_v1" "efs" {
  count = local.create_efs_storage_class ? 1 : 0
  
  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Delete"
  parameters = {
    # Dynamic provisioning
    provisioningMode = "efs-ap"
    fileSystemId     = var.efs_id
    directoryPerms   = "700"
    # Issue #190
    uid = "1000"
    gid = "1000"
  }

  mount_options = [
    "iam"
  ]
}