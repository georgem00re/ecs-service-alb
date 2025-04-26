
terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.95.0"
    }
  }

  // Ordinarily, we would want to store the tfstate in an S3 bucket,
  // but for this example, we are using a local backend to keep things simple.
  backend "local" {
    path = "./terraform.tfstate"
  }
}

provider "aws" {
  region  = "eu-west-2"
  profile = "admin"
}

// Fetches a list of currently available availability zones
// in the AWS region your provider is configured for (eu-west-2).
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  ecs = {
    cluster_name         = "my-ecs-cluster"
    service_name         = "my-ecs-service"
    task_definition_name = "my-ecs-task-definition"
    container_name       = "my-ecs-container"
  }
  availability_zone_a = data.aws_availability_zones.available.names[0]
  availability_zone_b = data.aws_availability_zones.available.names[1]

  cidr = {
    public_internet = "0.0.0.0/0"
    vpc             = "192.0.0.0/16"   // 192.0.0.0 to 192.0.255.255 (65,636 addresses).
    private_subnet  = "192.0.0.0/24"   // 192.0.0.0 – 192.0.0.255 (256 addresses).
    public_subnets  = "192.0.1.0/24"   // 192.0.1.0 - 192.0.1.255 (256 addresses).
    public_subnet_1 = "192.0.1.0/25"   // 192.0.1.0 - 192.0.1.127 (128 addresses).
    public_subnet_2 = "192.0.1.128/26" // 192.0.1.128 - 192.0.1.191 (64 addresses).
    public_subnet_3 = "192.0.1.192/26" // 192.0.1.192 - 192.0.1.255 (64 addresses).
  }
}

module "aws_vpc" {
  source     = "./modules/aws_vpc"
  cidr_block = local.cidr.vpc
}

module "aws_internet_gateway" {
  source = "./modules/aws_internet_gateway"
  vpc_id = module.aws_vpc.id
}

module "private_subnet" {
  source            = "./modules/aws_private_subnet"
  availability_zone = local.availability_zone_a
  cidr_block        = local.cidr.private_subnet
  vpc_id            = module.aws_vpc.id
  nat_gateway_id    = module.aws_nat_gateway.id
}

module "public_subnet_1" {
  source              = "./modules/aws_public_subnet"
  availability_zone   = local.availability_zone_a
  cidr_block          = local.cidr.public_subnet_1
  vpc_id              = module.aws_vpc.id
  internet_gateway_id = module.aws_internet_gateway.id
}

// We must create two public subnets because an ALB must be deployed across at least two subnets in two different
// availability zones. This ensures high availability. If one availability zone (or subnet) experiences an outage,
// the load balancer will continue to operate using the remaining availability zone.
module "public_subnet_2" {
  source              = "./modules/aws_public_subnet"
  availability_zone   = local.availability_zone_b
  cidr_block          = local.cidr.public_subnet_2
  vpc_id              = module.aws_vpc.id
  internet_gateway_id = module.aws_internet_gateway.id
}

// We are creating a third public subnet to hold the VPC's NAT gateway.
module "public_subnet_3" {
  source              = "./modules/aws_public_subnet"
  cidr_block          = local.cidr.public_subnet_3
  vpc_id              = module.aws_vpc.id
  internet_gateway_id = module.aws_internet_gateway.id

  // A NAT gateway is deployed in a single availability zone, and serves only private subnets in the same availability
  // zone. Therefore, our NAT gateway must be deployed in the same availability zone as the private subnet (i.e. AZ-A).
  availability_zone = local.availability_zone_a
}

// A NAT gateway is needed to allow the private subnet outbound internet connectivity so that it can pull the
// "nginxdemos/hello" image from DockerHub. We do not apply a NACL to this subnet. It is generally recommended to avoid
// applying restrictive NACL rules to the subnet containing your NAT gateway. NAT gateways are inherently secure, and
// overly restrictive NACL rules can interfere with their proper function.
module "aws_nat_gateway" {
  source    = "./modules/aws_nat_gateway"
  subnet_id = module.public_subnet_3.id

  # To ensure proper ordering, it is recommended to add an explicit dependency on the VPC's internet gateway.
  depends_on = [module.aws_internet_gateway]
}

module "alb_subnet_nacl" {
  source     = "./modules/aws_network_acl"
  subnet_ids = [module.public_subnet_1.id, module.public_subnet_2.id]
  vpc_id     = module.aws_vpc.id

  inbound_rules = [
    { // Allow HTTP traffic from the Internet.
      rule_number   = 100
      protocol      = "tcp"
      allow_or_deny = "allow"
      cidr_block    = local.cidr.public_internet
      from_port     = "80"
      to_port       = "80"
    },
    { // Allow return traffic from the ECS service in the private subnet.
      rule_number   = 110
      protocol      = "tcp"
      allow_or_deny = "allow"
      cidr_block    = local.cidr.private_subnet
      from_port     = "1024"
      to_port       = "65535"
    },
  ]
  outbound_rules = [
    { // Allow HTTP return traffic to the public Internet.
      rule_number   = 130
      protocol      = "tcp"
      allow_or_deny = "allow"
      cidr_block    = local.cidr.public_internet
      from_port     = "1024"
      to_port       = "65535"
    },
    { // Allow HTTP traffic to the ECS service in the private subnet.
      rule_number   = 140
      protocol      = "tcp"
      allow_or_deny = "allow"
      cidr_block    = local.cidr.private_subnet
      from_port     = "80"
      to_port       = "80"
    },
  ]
}

module "ecs_subnet_nacl" {
  source     = "./modules/aws_network_acl"
  subnet_ids = [module.private_subnet.id]
  vpc_id     = module.aws_vpc.id

  inbound_rules = [
    { // Allow HTTP traffic from the ALB in the public subnets.
      rule_number   = 100
      protocol      = "tcp"
      allow_or_deny = "allow"
      cidr_block    = local.cidr.public_subnets
      from_port     = "80"
      to_port       = "80"
    },
    { // Allow return traffic from the public Internet.
      rule_number   = 110
      protocol      = "tcp"
      allow_or_deny = "allow"
      cidr_block    = local.cidr.public_internet
      from_port     = "1024"
      to_port       = "65535"
    },
  ]
  outbound_rules = [
    { // Allow return traffic to the ALB in the public subnets.
      rule_number   = 120
      protocol      = "tcp"
      allow_or_deny = "allow"
      cidr_block    = local.cidr.public_subnets
      from_port     = "1024"
      to_port       = "65535"
    },
    { // Allow HTTPS traffic to the public Internet.
      rule_number   = 130
      protocol      = "tcp"
      allow_or_deny = "allow"
      cidr_block    = local.cidr.public_internet
      from_port     = "443"
      to_port       = "443"
    },
  ]
}

module "aws_ecs_cluster" {
  source       = "./modules/aws_ecs_cluster"
  cluster_name = local.ecs.cluster_name
}

module "aws_lb" {
  source          = "./modules/aws_lb"
  subnets         = [module.public_subnet_1.id, module.public_subnet_2.id]
  security_groups = [module.aws_lb_security_group.id]
}

module "aws_lb_security_group" {
  source = "./modules/aws_security_group"
  vpc_id = module.aws_vpc.id

  // This allows all inbound HTTP traffic from the public Internet.
  inbound_rules = [{
    cidr_ipv4   = local.cidr.public_internet
    from_port   = 80
    ip_protocol = "tcp"
    to_port     = 80
  }]
  // This allows outbound HTTP traffic to the security group of the ECS service.
  outbound_rules = [{
    security_group_id = module.aws_ecs_service_security_group.id
    from_port         = 80
    ip_protocol       = "tcp"
    to_port           = 80
  }]
}

module "aws_lb_target_group" {
  source   = "./modules/aws_lb_target_group"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = module.aws_vpc.id
}

module "aws_lb_listener" {
  source            = "./modules/aws_lb_listener"
  load_balancer_arn = module.aws_lb.arn
  port              = "80"
  protocol          = "HTTP"
  target_group_arn  = module.aws_lb_target_group.arn

  // Normally, we would want to use an SSL/TLS certificate to encrypt HTTP traffic 
  // between the client and load balancer. However, to obtain a certificate, you must
  // provide proof of ownership of a domain name, which we don't have. Therefore, we 
  // are using (unencrypted) HTTP instead.
  certificate_arn = null
}

module "aws_lb_listener_rule" {
  source           = "./modules/aws_lb_listener_rule"
  listener_arn     = module.aws_lb_listener.arn
  priority         = 100
  target_group_arn = module.aws_lb_target_group.arn
}

module "aws_ecs_service" {
  source                         = "./modules/aws_ecs_service"
  name                           = local.ecs.service_name
  cluster_id                     = module.aws_ecs_cluster.id
  desired_count                  = 1
  memory                         = 2048
  cpu                            = 1024
  image_url                      = "nginxdemos/hello"
  container_port                 = 80
  host_port                      = 80
  subnets                        = [module.private_subnet.id]
  container_name                 = local.ecs.container_name
  task_definition_name           = local.ecs.task_definition_name
  load_balancer_target_group_arn = module.aws_lb_target_group.arn
  security_groups                = [module.aws_ecs_service_security_group.id]
  depends_on                     = [module.aws_lb_listener_rule, module.aws_lb_target_group, module.aws_lb]
}

module "aws_ecs_service_security_group" {
  source = "./modules/aws_security_group"
  vpc_id = module.aws_vpc.id

  // This allows inbound HTTP traffic from the security group of the ALB.
  inbound_rules = [{
    security_group_id = module.aws_lb_security_group.id
    from_port         = 80
    ip_protocol       = "tcp"
    to_port           = 80
  }]

  // This allows outbound HTTPS traffic to the Internet, enabling the ECS service
  // to pull the "nginxdemos/hello" image from DockerHub.
  outbound_rules = [{
    cidr_ipv4   = local.cidr.public_internet
    from_port   = 443
    ip_protocol = "tcp"
    to_port     = 443
  }]
}

module "aws_appautoscaling_ecs" {
  source           = "./modules/aws_appautoscaling_ecs"
  max_capacity     = 5
  min_capacity     = 1
  ecs_cluster_name = module.aws_ecs_cluster.name
  ecs_service_name = module.aws_ecs_service.name
  target_tracking_scaling_policies = [
    {
      metric_type  = "ECSServiceAverageMemoryUtilization"
      target_value = 80
    },
    {
      metric_type  = "ECSServiceAverageCPUUtilization"
      target_value = 60
    }
  ]
}
