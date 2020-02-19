// iam junk for eks cluster
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}

// iam junk for eks nodes

// get the thumbprint for oidc
// hopefully there is a better way to do this soon - https://github.com/terraform-providers/terraform-provider-aws/issues/10104
data "external" "thumbprint" {
  program = ["./thumbprint.sh", "us-west-2"]
}

// enable iam roles for service accounts
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.external.thumbprint.result.thumbprint]
  url             = aws_eks_cluster.av.identity.0.oidc.0.issuer
}

data "aws_iam_policy_document" "eks_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "eks_node_group" {
  name               = "eks-node-group-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "eks_node_group-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_node_group-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_node_group-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

// eks cluster
resource "aws_eks_cluster" "av" {
  name     = "av"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    // https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
    subnet_ids = concat(module.acs.private_subnet_ids, module.acs.public_subnet_ids)
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster-AmazonEKSServicePolicy
  ]
}

// create the node group
resource "aws_eks_node_group" "av_node_group" {
  cluster_name    = aws_eks_cluster.av.name
  node_group_name = "av-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = module.acs.private_subnet_ids

  ami_type       = "AL2_x86_64"
  disk_size      = "10"
  instance_types = ["m5.large"]

  scaling_config {
    desired_size = 3
    max_size     = 6
    min_size     = 3
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_group-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_node_group-AmazonEC2ContainerRegistryReadOnly,
  ]
}
