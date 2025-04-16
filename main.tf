provider "aws" {
  region = var.aws_region
}

# Fetch available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "alb-vpc"
  }
}

# Create Subnets
resource "aws_subnet" "subnets" {
  count                   = length(var.subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs[count.index]
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-${count.index + 1}"
  }
}

#create internet geteway

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
    tags {
        name = "alb-igw"
    }
}

#create route table

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "alb-rt"
  }
}

# Associate Route Table with Subnets

resource "aws_route_table_association" "rta" {
  count          = length(var.subnet_cidrs)
  subnet_id      = aws_subnet.subnets[count.index].id
  route_table_id = aws_route_table.rt.id
}

# Create Security Group for ALB

resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol =  "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group for EC2 Instances
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create EC2 Instances
resource "aws_instance" "instances" {
  count                  = 3
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subnets[count.index].id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data              = templatefile("${path.module}/user_data/instance_${count.index + 1}.sh", {})
  tags = {
    Name = "instance-${count.index + 1}"
  }
}

# Create ALB

resource "aws_lb" "alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.subnets[*].id
}

# Create Target Groups
resource "aws_lb_target_group" "tg" {
  count    = 3
  name     = "tg-${count.index + 1}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Attach EC2 Instances to Target Groups
resource "aws_lb_target_group_attachment" "tga" {
  count            = 3
  target_group_arn = aws_lb_target_group.tg[count.index].arn
  target_id        = aws_instance.instances[count.index].id
}

# Create Listener and Rules
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[0].arn
  }
}

resource "aws_lb_listener_rule" "rule" {
  count        = 2
  listener_arn = aws_lb_listener.listener.arn
  priority     = count.index + 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg[count.index + 1].arn
  }

  condition {
    path_pattern {
      values = [count.index == 0 ? "/images/*" : "/register/*"]
    }
  }
}








