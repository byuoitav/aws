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
