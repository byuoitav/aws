terraform {
  backend "s3" {
    bucket = "terraform-state-storage-586877430255"
    lock_table = "terraform-state-lock-586877430255"
    key = "base-account-config.tfstate"
    region = "us-west-2"
  }
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
