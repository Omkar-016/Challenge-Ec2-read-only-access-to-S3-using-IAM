terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~5.0"
    }
  }
}

provider "aws" {
    region = var.aws_region

}

#VPC setup , so we get subnets

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    tags = {
        name = "${var.Challenge}-vpc"
    }

}

resource "aws_subnet" "private" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = false

}

#security group for internal connection

resource "aws_security_group" "ec_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    protocol  = "tcp"
    from_port = "22"
    to_port   = "22"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
} 

#IAM role for Ec2 to read S3
resource "aws_iam_role" "Ec2-role" {
  name = "${var.Challenge}-Ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "read-only-s3" {
    name = "${var.Challenge}-read-only-s3"
      policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:Get*",
          "s3:List*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_read_only" {
  role       = aws_iam_role.Ec2-role.name
  policy_arn = aws_iam_policy.read-only-s3.arn
}

resource "aws_iam_instance_profile" "Ec2_profile" {
  name = "${var.Challenge}-Ec2-profile"
  role = aws_iam_role.Ec2-role.name
}


# EC2 instance in private subnet (without any public IP)
resource "aws_instance" "ec2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.ec_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.Ec2_profile.name
  associate_public_ip_address = false
}

#creating a S3
resource "aws_s3_bucket" "Challenge_bucket" {
    bucket = "${var.Challenge}-challenge-bucket"
    force_destroy = false  # if S3 has a data in it terraform cant delete it and throw a error of "Error: BucketNotEmpty: The bucket you tried to delete is not empty"
                #if true then  S3 has a data in it it will delete both the data and S3

  
}

#enabling version in this bucket
resource "aws_s3_bucket_versioning" "enabling_versioning" { 
  bucket = aws_s3_bucket.Challenge_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

#encryption of s3 if needed
# resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
#   bucket = aws_s3_bucket.challenge_bucket.id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# Blocking all public access
resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.Challenge_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
