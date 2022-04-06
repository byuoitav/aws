module "postgres" {
  source = "github.com/byu-oit/terraform-aws-rds?ref=v2.3.1"

  identifier              = "av-main"
  instance_class          = "db.t3.small"
  engine                  = "postgres"
  engine_version          = "13.1"
  family                  = "postgres13"
  cloudwatch_logs_exports = ["postgresql", "upgrade"]

  db_name           = "av"
  subnet_ids        = module.acs.data_subnet_ids
  subnet_group_name = module.acs.db_subnet_group_name
  vpc_id            = module.acs.vpc.id

  ssm_prefix = "/rds/av-main"
  tags = {
    env              = "prd"
    team             = "av"
    data-sensitivity = "private"
  }

}
