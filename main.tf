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
# Private subnet
resource "aws_subnet" "private" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = false
    tags = {
      name = "${var.Challenge}-private-sb"
    }


}

#public subnet , for the NAT gw  
resource "aws_subnet" "public" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.0.0/24"
    map_public_ip_on_launch = true
    tags = {
      name = "${var.Challenge}-public-sb"
    }

}
#internet gw
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    name = "${var.Challenge}-igw"
  }
  
}

#elastic ip for nat gw
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags ={
    name = "${var.Challenge}-nat-eip"
  }
  
}

#nat gateway 
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  tags = {
    name = "${var.Challenge}-nat-gateway"
  }
}
 
# Public Route Table (for public subnet)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    name = "${var.Challenge}-public-rt"
  }
}

# Associate public route table with public subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route table (for Private subnet , Via NAT gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    name = "${var.Challenge}-private-rt"
  }
}

# Associate private route table with private subnet
resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
}

#security group for internal connection
resource "aws_security_group" "ec_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "${var.Challenge}-sg"
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
  tags = {
    name = "${var.Challenge}-ec2"
  }
}

#creating a S3
resource "aws_s3_bucket" "Challenge_bucket" {
    bucket = "${var.Challenge}-challenge-bucket"
    force_destroy = false  # if S3 has a data in it terraform cant delete it and throw a error of "Error: BucketNotEmpty: The bucket you tried to delete is not empty"
                #if true then  S3 has a data in it it will delete both the data and S3
    tags = {
     name = "${var.Challenge}-S3"
  }
  
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
