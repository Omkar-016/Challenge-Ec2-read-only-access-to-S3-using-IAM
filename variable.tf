variable "aws_region" {
    default = "ap-south-1"
  
}

variable "Challenge" {
    default = "aws_secure-internship"
  
}

variable "ami" {
    description = "Required Ami for  project"
    type = string 
    default = "ami-0cd9e9cb4206beed5" #centos 10 
  
}

variable "instance_type" {
    description = "put your required instance-type"
    type = string
    default = "t3.micro"
  
}
