provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "CHANGE_BUCKET"
    key    = "terraform/state"
    region = "us-east-1"
  }
}

resource "aws_eks_cluster" "primary" {
  count           = var.destroy == true ? 0 : 1
  name            = var.cluster_name
  role_arn        = aws_iam_role.control_plane[0].arn
  version         = var.k8s_version

  vpc_config {
    security_group_ids = [aws_security_group.worker[0].id]
    subnet_ids         = aws_subnet.worker[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_iam_role_policy_attachment.service,
  ]
}

resource "aws_eks_node_group" "primary" {
  count           = var.destroy == true ? 0 : 1
  cluster_name    = aws_eks_cluster.primary[0].name
  version         = var.k8s_version
  release_version = var.release_version
  node_group_name = "devops-catalog"
  node_role_arn   = aws_iam_role.worker[0].arn
  subnet_ids      = aws_subnet.worker[*].id
  instance_types  = [var.machine_type]
  scaling_config {
    desired_size = var.min_node_count
    max_size     = var.max_node_count
    min_size     = var.min_node_count
  }
  depends_on = [
    aws_iam_role_policy_attachment.worker,
    aws_iam_role_policy_attachment.cni,
    aws_iam_role_policy_attachment.registry,
  ]
  timeouts {
    create = "15m"
    update = "1h"
  }
}

resource "aws_iam_role" "control_plane" {
  count = var.destroy == true ? 0 : 1
  name  = "devops-catalog-control-plane"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster" {
  count      = var.destroy == true ? 0 : 1
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.control_plane[0].name
}

resource "aws_iam_role_policy_attachment" "service" {
  count      = var.destroy == true ? 0 : 1
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.control_plane[0].name
}

resource "aws_vpc" "worker" {
  count      = var.destroy == true ? 0 : 1
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name"                                      = "devops-catalog"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_security_group" "worker" {
  count       = var.destroy == true ? 0 : 1
  name        = "devops-catalog"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.worker[0].id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "devops-catalog"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "worker" {
  count                   = var.destroy == true ? 0 : 3
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.${count.index}.0/24"
  vpc_id                  = aws_vpc.worker[0].id
  map_public_ip_on_launch = true
  tags = {
    "Name"                                      = "devops-catalog"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_iam_role" "worker" {
  count              = var.destroy == true ? 0 : 1
  name               = "devops-catalog-worker"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "worker" {
  count      = var.destroy == true ? 0 : 1
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker[0].name
}

resource "aws_iam_role_policy_attachment" "cni" {
  count      = var.destroy == true ? 0 : 1
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker[0].name
}

resource "aws_iam_role_policy_attachment" "registry" {
  count      = var.destroy == true ? 0 : 1
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.worker[0].name
}

resource "aws_internet_gateway" "worker" {
  count  = var.destroy == true ? 0 : 1
  vpc_id = aws_vpc.worker[0].id
  tags   = {
    Name = "devops-catalog"
  }
}

resource "aws_route_table" "worker" {
  count  = var.destroy == true ? 0 : 1
  vpc_id = aws_vpc.worker[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.worker[0].id
  }
}

resource "aws_route_table_association" "worker" {
  count  = var.destroy == true ? 0 : 3
  subnet_id      = aws_subnet.worker[count.index].id
  route_table_id = aws_route_table.worker[0].id
}
