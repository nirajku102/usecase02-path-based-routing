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
    vpc_id = aws_vpc.id
    tage {
        name = "alb-igw"
    }
}

