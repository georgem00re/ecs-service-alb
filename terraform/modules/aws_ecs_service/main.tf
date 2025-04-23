
resource "aws_ecs_service" "this" {
  name = var.name
  cluster = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count = var.desired_count
  launch_type = "FARGATE"

  network_configuration {
    subnets = var.subnets
    assign_public_ip = false
    security_groups = var.security_groups
  }

  load_balancer {
    target_group_arn = var.load_balancer_target_group_arn
    container_port = var.container_port

    // This is the name of the container in your task definition
    // that the load balancer should forward traffic to.
    container_name = var.container_name
  }
}

resource "aws_ecs_task_definition" "this" {
  family = var.task_definition_name
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  memory = var.memory
  cpu = var.cpu

  // The execution role is used by the Amazon ECS service to pull the container image,
  // fetch secrets, legs, etc. when starting the ECS task.
  execution_role_arn = aws_iam_role.this.arn

  container_definitions = jsonencode([{
    name = var.container_name
    image = var.image_url

    // If the container exits or fails, ECS will stop the task. When the
    // task fails, the ECS service replaces it automatically.
    essential = true

    portMappings = [{
      containerPort = var.container_port
      hostPort = var.host_port
    }]
  }])
}

resource "aws_iam_role" "this" {
  name = "ecs_task_execution_role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17"
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  role = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
