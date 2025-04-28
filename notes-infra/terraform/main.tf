/*
Terraform configuration for AWS EKS cluster, VPC, and ECR with S3 backend & DynamoDB locking.
Ensure you replace `state_bucket_name` and `lock_table_name` with your actual values.
*/

terraform {
  required_version = ">= 1.3.0"

  backend "s3" {
    bucket         = "notes-app-tfstate-123456"      # from bootstrap
    key            = "notes-app/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "notes-app-tfstate-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "notes-cluster"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  name = "notes-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "dev"
    Project     = "notes-app"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.17.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.32"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false
  
  tags = {
    Environment = "dev"
    Project     = "notes-app"
  }
}

resource "aws_iam_role" "example" {
  name = "eks-node-group-example"

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

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.example.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.example.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.example.name
}


resource "aws_eks_node_group" "example" {
  cluster_name    =  module.eks.cluster_name
  node_group_name =  "example-node-group"
  node_role_arn   =  aws_iam_role.example.arn
  subnet_ids    =  module.vpc.private_subnets

  scaling_config {
    desired_size = 5
    max_size     = 6
    min_size     = 1
  }
}
resource "aws_ecr_repository" "notes_app" {
  name                 = "notes-app"
  image_tag_mutability = "MUTABLE"
  tags = {
    Environment = "dev"
    Project     = "notes-app"
  }
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "EKS cluster security group id"
  value       = module.eks.cluster_security_group_id
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.notes_app.repository_url
}
