#--------------
#VPC Definition
#--------------
resource "aws_vpc" "istrat_vpc" {
  cidr_block           = "172.20.0.0/16"
  instance_tenancy     = "default"

  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name               = "istrat_vpc"
  }
}

#------------
# Data for AZ
#------------
data "aws_availability_zones" "azs" {
  state = "available"
}


#-------------------
# Subnet Settings A
#-------------------
resource "aws_subnet" "istrat_net" {
  count                   = 3
  cidr_block              = cidrsubnet(aws_vpc.istrat_vpc.cidr_block, 12, 3 + count.index)
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  vpc_id                  = aws_vpc.istrat_vpc.id
#  cidr_block              = "172.20.1.0/24"

  map_public_ip_on_launch = "true"

  tags = {
    Name                  = "istrat_net_${count.index}"
  }
}


#--------------------
#Route Table Settings
#--------------------
resource "aws_route_table" "istrat_rt" {
  vpc_id                  = aws_vpc.istrat_vpc.id

  route {
    cidr_block            = "0.0.0.0/0"
    gateway_id            = aws_internet_gateway.istrat_igw.id
  }

  tags = {
    Name                  = "istrat_RT"
  }
}

#--------------------------
#Route Table Association A
#--------------------------
resource "aws_route_table_association" "rt_a" {
  count                   = 3
  subnet_id               = element(aws_subnet.istrat_net.*.id, count.index)
  route_table_id          = element(aws_route_table.istrat_rt.*.id, count.index)
}


#----------------
#Internet Gateway
#----------------
resource "aws_internet_gateway" "istrat_igw" {
  vpc_id                  = aws_vpc.istrat_vpc.id

  tags = {
    Name                  = "istrat_igw"
  }
}


#######################
## SECURITY GROUP    ##
#######################
#--------
# Locals
#--------

locals {
    ports_tcp	= [22,80,443,3000]
}


#-------------
#Outbound Rule
#-------------
resource "aws_security_group_rule" "egress" {

  type        = "egress"
  from_port   = 0 
  to_port     = 0
  protocol    = "-1"  # -1 means all protocols
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.istrat_sg.id}"
}

#---------------
# Security Group
#---------------

resource "aws_security_group" "istrat_sg" {
  name        		= "istrat_SG"
  description 		= "Allow TLS inbound traffic"
  vpc_id      		= "${aws_vpc.istrat_vpc.id}"


  dynamic "ingress" {
    for_each		= toset(local.ports_tcp)
    content {
      description      	= "TLS from VPC"
      from_port        	= ingress.value
      to_port          	= ingress.value
      protocol         	= "tcp"
      cidr_blocks      	= ["0.0.0.0/0"]
}
}


tags = {
  "Name"	= "istrat_SG"
}
}

#######################
## ECS CLUSTER       ##
#######################

#-----------
#ECS Cluster
#-----------
resource "aws_ecs_cluster" "istrat-ecs" {
  name = "istrat-Cluster"
}


#----------------
#Service Settings
#----------------
resource "aws_ecs_service" "istrat-svc" {
  name            = "react-app-svc"
  cluster         = aws_ecs_cluster.istrat-ecs.id
  task_definition = aws_ecs_task_definition.istrat_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = "${[aws_security_group.istrat_sg.id]}"
    subnets         = "${aws_subnet.istrat_net.*.id}"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.istrat-tg.id
    container_name   = "react-app"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.istrat-lis]
}



#---------------
#Task Definistion
#---------------
resource "aws_ecs_task_definition" "istrat_task" {
  family                   = "react-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048

  container_definitions = <<DEFINITION
[
  {
    "image": "public.ecr.aws/g0b5g9q2/istrat-ecr:latest",
    "cpu": 1024,
    "memory": 2048,
    "name": "react-app",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": 3000,
        "hostPort": 3000
      }
    ]
  }
]
DEFINITION
}


#######################
## LOAD BALANCER     ##
#######################

#----------------------
# LoadBalancer Settings
#----------------------
resource "aws_lb" "istrat-lb" {
  name               = "istrat-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = "${[aws_security_group.istrat_sg.id]}"
  subnets            = "${aws_subnet.istrat_net.*.id}"


  tags = {
    Name             = "istrat-lb"
  }
}


#----------------------
# Target Group Settings
#----------------------
resource "aws_lb_target_group" "istrat-tg" {
  name         = "istrat-tg"
  port         = 80
  protocol     = "HTTP"
  vpc_id       = "${aws_vpc.istrat_vpc.id}"
  target_type  = "ip"

  tags = {
    Name             = "istrat-TG"
  }
}

#----------------------
# LB Listener Settings
#----------------------
resource "aws_lb_listener" "istrat-lis" {
  load_balancer_arn         = "${aws_lb.istrat-lb.id}"
  port                      = 80
  protocol                  = "HTTP"
  
  default_action {
    target_group_arn        = "${aws_lb_target_group.istrat-tg.id}"
    type                    = "forward"
  

  }
}
