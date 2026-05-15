module "vpc" {
  source       = "./modules/networking"
  vpc_cidr     = var.vpc_cidr
  project_name = var.project_name
  environment  = var.environment
}

module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
  environment  = var.environment
}

module "ec2" {
  source               = "./modules/compute"
  project_name         = var.project_name
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  public_subnet_id     = module.vpc.public_subnet_ids[0]
  iam_instance_profile = module.iam.instance_profile_name
  my_ip                = var.my_ip
}

module "rds" {
  source             = "./modules/database"
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ec2_sg_id          = module.ec2.sg_id
  db_password        = var.db_password
}

module "lookout" {
  source       = "./modules/lookout"
  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email
}
