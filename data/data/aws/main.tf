locals {
  tags = "${merge(map(
    "kubernetes.io/cluster/${var.cluster_id}", "owned"
  ), var.aws_extra_tags)}"
}

provider "aws" {
  region = "${var.aws_region}"
}

module "bootstrap" {
  source = "./bootstrap"

  ami                      = "${var.aws_ec2_ami_override}"
  instance_type            = "${var.aws_bootstrap_instance_type}"
  cluster_id               = "${var.cluster_id}"
  ignition                 = "${var.ignition_bootstrap}"
  subnet_id                = "${module.vpc.public_subnet_ids[0]}"
  target_group_arns        = "${module.vpc.aws_lb_target_group_arns}"
  target_group_arns_length = "${module.vpc.aws_lb_target_group_arns_length}"
  vpc_id                   = "${module.vpc.vpc_id}"
  vpc_security_group_ids   = "${list(module.vpc.master_sg_id)}"

  tags = "${local.tags}"
}

module "masters" {
  source = "./master"

  cluster_id    = "${var.cluster_id}"
  instance_type = "${var.aws_master_instance_type}"

  tags = "${local.tags}"

  instance_count           = "${var.master_count}"
  master_sg_ids            = "${list(module.vpc.master_sg_id)}"
  root_volume_iops         = "${var.aws_master_root_volume_iops}"
  root_volume_size         = "${var.aws_master_root_volume_size}"
  root_volume_type         = "${var.aws_master_root_volume_type}"
  subnet_ids               = "${module.vpc.private_subnet_ids}"
  target_group_arns        = "${module.vpc.aws_lb_target_group_arns}"
  target_group_arns_length = "${module.vpc.aws_lb_target_group_arns_length}"
  ec2_ami                  = "${var.aws_ec2_ami_override}"
  user_data_ign            = "${var.ignition_master}"
}

module "iam" {
  source = "./iam"

  cluster_id = "${var.cluster_id}"

  tags = "${local.tags}"
}

module "dns-api" {
  source = "./route53/api"

  api_external_lb_dns_name = "${module.vpc.aws_lb_api_external_dns_name}"
  api_external_lb_zone_id  = "${module.vpc.aws_lb_api_external_zone_id}"
  api_internal_lb_dns_name = "${module.vpc.aws_lb_api_internal_dns_name}"
  api_internal_lb_zone_id  = "${module.vpc.aws_lb_api_internal_zone_id}"
  base_domain              = "${var.base_domain}"
  cluster_domain           = "${var.cluster_domain}"
  cluster_id               = "${var.cluster_id}"
  tags                     = "${local.tags}"
  vpc_id                   = "${module.vpc.vpc_id}"
}

module "dns-etcd" {
  source = "./route53/etcd"

  zone_id        = "${module.dns-api.int_zone_id}"
  cluster_domain = "${var.cluster_domain}"

  etcd_count        = "${var.master_count}"
  etcd_ip_addresses = "${module.masters.ip_addresses}"
}

module "vpc" {
  source = "./vpc"

  cidr_block = "${var.machine_cidr}"
  cluster_id = "${var.cluster_id}"
  region     = "${var.aws_region}"

  tags = "${local.tags}"
}
