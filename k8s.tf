provider "kubernetes" {
  host = aws_eks_cluster.eks.endpoint

  client_certificate = aws_eks_cluster.eks.certificate_authority.0.data
}
