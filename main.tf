terraform {
  backend "s3" {
    bucket         = "terraform-state-storage-586877430255"
    dynamodb_table = "terraform-state-lock-586877430255"
    key            = "base-account-config.tfstate"
    region         = "us-west-2"
  }
  //  required_providers {
  //    aws = {
  //      source  = "hashicorp/aws"
  //      version = "~> 3.0"
  //    }
  //    helm = {
  //      source  = "hashicorp/helm"
  //      version = "~> 2.0"
  //    }
  //    external = {
  //      source  = "hashicorp/external"
  //      version = "~> 2.1"
  //    }
  //    kubernetes = {
  //      source  = "hashicorp/kubernetes"
  //      version = "~> 2.0.2"
  //    }
  //  }
}

provider "aws" {
  region = "us-west-2"
}

// import information from byu acs
module "acs" {
  source            = "github.com/byuoitav/terraform//modules/acs-info"
  env               = "prd"
  department_name   = "av"
  vpc_vpn_to_campus = true
}
