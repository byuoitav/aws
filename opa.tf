resource "aws_s3_bucket" "opa_bucket" {
  bucket = "byuoitav-opa-policies"
  acl    = "private"
  tags = {
    env              = "prd"
    data-sensitivity = "confidential"
    team             = "AV Engineering"
  }
}

module "statefulset_dev" {
  source = "github.com/byuoitav/terraform//modules/kubernetes-statefulset"

  // required
  name                 = "opa-dev"
  image                = "openpolicyagent/opa"
  image_version        = "latest"
  container_port       = 8181
  repo_url             = "https://github.com/byuoitav/aws"
  storage_mount_path   = "/opt/policies"
  storage_request_size = "10Gi"

  // optional
  container_env = {}
  container_args = [
    "run", "--server",
    "--log-level", "debug"
  ]
}
