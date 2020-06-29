locals {
  couch_name = "couchdb"
}

provider "helm" {}

resource "aws_route53_record" "couch" {
  zone_id = data.aws_ssm_parameter.r53_zone_id.value
  name    = "couch.av.byu.edu"
  type    = "A"

  alias {
    name                   = data.aws_lb.eks_lb.dns_name
    zone_id                = data.aws_lb.eks_lb.zone_id
    evaluate_target_health = false
  }
}

data "aws_ssm_parameter" "couch_uuid" {
  name = "/couch/uuid"
}

data "aws_ssm_parameter" "couch_user" {
  name = "/couch/username"
}

data "aws_ssm_parameter" "couch_password" {
  name = "/couch/password"
}

resource "helm_release" "couch_cluster" {
  name       = "production-couch-cluster"
  repository = "https://apache.github.io/couchdb-helm"
  chart      = "couchdb"
  version    = "3.3.2"

  values = [
    yamlencode({
      ingress = {
        tls = [
          {
            secretName = "star-av-byu-edu"
            hosts = [
              "couch.av.byu.edu"
            ]
          }
        ]
      }
    }),
  ]

  set {
    name  = "adminUsername"
    value = data.aws_ssm_parameter.couch_user.value
  }

  set {
    name  = "adminPassword"
    value = data.aws_ssm_parameter.couch_password.value
  }

  set {
    name  = "clusterSize"
    value = "3"
  }

  set {
    name  = "persistentVolume.enabled"
    value = "true"
  }

  set {
    name  = "couchdbConfig.couchdb.uuid"
    value = data.aws_ssm_parameter.couch_uuid.value
  }

  set {
    name  = "couchdbConfig.chttpd.require_valid_user"
    value = "true"
  }

  set {
    name  = "couchdbConfig.httpd.WWW-Authenticate"
    value = "Basic realm=\"administrator\""
  }

  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.hosts"
    value = "{couch.av.byu.edu}"
  }

}
