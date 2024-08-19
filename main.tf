provider "aws" {
  region = "ap-south-1"
}

# Create a VPC
resource "aws_vpc" "vulnerable_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create a subnet
resource "aws_subnet" "vulnerable_subnet" {
  vpc_id     = aws_vpc.vulnerable_vpc.id
  cidr_block = "10.0.1.0/24"
}

# Create an Internet Gateway
resource "aws_internet_gateway" "vulnerable_igw" {
  vpc_id = aws_vpc.vulnerable_vpc.id
}

# Create a route table
resource "aws_route_table" "vulnerable_route_table" {
  vpc_id = aws_vpc.vulnerable_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vulnerable_igw.id
  }
}

# Associate route table with the subnet
resource "aws_route_table_association" "vulnerable_route_table_assoc" {
  subnet_id      = aws_subnet.vulnerable_subnet.id
  route_table_id = aws_route_table.vulnerable_route_table.id
}

# Create a Security Group with wide-open permissions
resource "aws_security_group" "vulnerable_sg" {
  vpc_id = aws_vpc.vulnerable_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an S3 bucket with public access
resource "aws_s3_bucket" "vulnerable_bucket" {
  bucket = "vulnerable-bucket-terraform"

  # Enabling public access through bucket policy instead of ACL
  force_destroy = true
}

resource "aws_s3_bucket_policy" "vulnerable_bucket_policy" {
  bucket = aws_s3_bucket.vulnerable_bucket.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": "*",
        "Action": [
          "s3:GetObject"
        ],
        "Resource": [
          "${aws_s3_bucket.vulnerable_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Launch an EC2 instance in the public subnet
resource "aws_instance" "vulnerable_instance" {
  ami           = "ami-0c55b159cbfafe1f0"  # Example for Amazon Linux 2
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.vulnerable_subnet.id
  security_groups = [aws_security_group.vulnerable_sg.name]

  tags = {
    Name = "VulnerableInstance"
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World!" > /var/www/html/index.html
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              EOF
}

# IAM Vulnerable Resources

# Create an IAM user with overly permissive policies
resource "aws_iam_user" "vulnerable_user" {
  name = "vulnerable-user"
}

# Attach a policy to the user with overly broad permissions
resource "aws_iam_user_policy" "vulnerable_user_policy" {
  name   = "vulnerable-policy"
  user   = aws_iam_user.vulnerable_user.name

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "*",
        "Resource": "*"
      }
    ]
  })
}

# Create an IAM role with wildcard actions in the policy
resource "aws_iam_role" "vulnerable_role" {
  name = "vulnerable-role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

# Attach a policy to the role with excessive permissions
resource "aws_iam_role_policy" "vulnerable_role_policy" {
  name = "vulnerable-role-policy"
  role = aws_iam_role.vulnerable_role.name

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "*",
        "Resource": "*"
      }
    ]
  })
}

# Attach the vulnerable role to the EC2 instance
resource "aws_iam_instance_profile" "vulnerable_instance_profile" {
  name = "vulnerable-instance-profile"
  role = aws_iam_role.vulnerable_role.name
}

resource "aws_instance" "vulnerable_instance_with_iam" {
  ami           = "ami-0c55b159cbfafe1f0"  # Example for Amazon Linux 2
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.vulnerable_subnet.id
  security_groups = [aws_security_group.vulnerable_sg.name]
  iam_instance_profile = aws_iam_instance_profile.vulnerable_instance_profile.name

  tags = {
    Name = "VulnerableInstanceWithIAM"
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World!" > /var/www/html/index.html
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              EOF
}

# Output the instance's public IP
output "instance_ip" {
  value = aws_instance.vulnerable_instance.public_ip
}

# Output the instance with IAM's public IP
output "instance_with_iam_ip" {
  value = aws_instance.vulnerable_instance_with_iam.public_ip
}

# Output the S3 bucket name
output "bucket_name" {
  value = aws_s3_bucket.vulnerable_bucket.bucket
}

# Output IAM user name
output "iam_user" {
  value = aws_iam_user.vulnerable_user.name
}

# Output IAM role name
output "iam_role" {
  value = aws_iam_role.vulnerable_role.name
}
