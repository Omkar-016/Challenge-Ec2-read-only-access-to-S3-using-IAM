output "ec2_instance_id" {
  value = aws_instance.ec2.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.Challenge_bucket.bucket
}
