module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.26"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    default = {
      name                       = "obs-ng-default"
      use_name_prefix            = false
      iam_role_name              = "obs-eks-node-role"
      iam_role_use_name_prefix   = false
      instance_types             = [var.node_instance_type]
      capacity_type              = "ON_DEMAND"

      min_size     = 1
      max_size     = 6
      desired_size = var.node_desired_size

      disk_size = 50

      labels = {
        role = "platform"
      }
    }
  }
}
