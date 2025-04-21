
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.54.1"
    }
  }

  // Ordinarily, we would want to store the tfstate in an S3 bucket,
  // but for this example, we are using a local backend to keep things simple.
  backend "local" {
    path = "./terraform.tfstate"
  }
}

provider "aws" {
  region = "eu-west-2"
}

// Fetches a list of currently available availability zones
// in the AWS region your provider is configured for (eu-west-2).
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  ecs_cluster_name = "my-cluster"
  ecs_service_name = "my-ecs-service"
  availability_zone_a = data.aws_availability_zones.available.names[0]
  availability_zone_b = data.aws_availability_zones.available.names[1]
  container_name = "my-container"
  task_definition_name = "my-task-definition"
}

module "aws_vpc" {
  source = "./modules/aws_vpc"
  cidr_block = "192.0.0.0/16" // 192.0.0.0 to 192.0.255.255
}

module "aws_internet_gateway" {
  source = "./modules/aws_internet_gateway"
  vpc_id = module.aws_vpc.id
}

module "private_subnet" {
  source = "./modules/aws_subnet"
  availability_zone = local.availability_zone_a
  cidr_block = "192.0.0.0/24" // 192.0.0.0 – 192.0.0.255
  vpc_id = module.aws_vpc.id
  internet_gateway_id = module.aws_internet_gateway.id
}

module "public_subnet" {
  source = "./modules/aws_subnet"
  availability_zone = local.availability_zone_b
  cidr_block = "192.0.1.0/24" // 192.0.1.0 – 192.0.1.255
  vpc_id = module.aws_vpc.id
  internet_gateway_id = module.aws_internet_gateway.id
}

module "ecs_cluster" {
  source = "./modules/aws_ecs_cluster"
  cluster_name = local.ecs_cluster_name
}

module "aws_lb" {
  source = "./modules/aws_lb"
}

module "aws_lb_target_group" {
  source = "./modules/aws_lb_target_group"
  name   = "ecs-target-group"
  port   = "80"
  protocol = "HTTP"
  vpc_id = module.aws_vpc.id
}

module "aws_lb_listener" {
  source = "./modules/aws_lb_listener"
  load_balancer_arn = module.aws_lb.arn
  port = "80"
  protocol = "HTTP"
  target_group_arn = module.aws_lb_target_group.arn
  certificate_arn = null
}

module "aws_lb_listener_rule" {
  source = "./modules/aws_lb_listener_rule"
  listener_arn = module.aws_lb_listener.arn
  priority = 100
  target_group_arn = module.aws_lb_target_group.arn
}

module "ecs_service" {
  source = "./modules/aws_ecs_service"
  name = local.ecs_service_name
  cluster_id = module.ecs_cluster.id
  desired_count = 1
  memory = 2048
  cpu = 1024
  image_url = "nginx:latest"
  container_port = 80
  host_port = 80
  subnets = [module.private_subnet.id]
  container_name = local.container_name
  task_definition_name = local.task_definition_name
  load_balancer_target_group_arn = module.aws_lb_target_group.arn
}
