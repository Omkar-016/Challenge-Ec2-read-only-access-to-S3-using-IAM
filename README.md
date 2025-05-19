# Challenge-Ec2-read-only-access-to-S3-using-IAM

visual_representation_of_challenge
![image alt](https://github.com/Omkar-016/Challenge-Ec2-read-only-access-to-S3-using-IAM/blob/4656a1318710e21b61068ad8d5167f728f120604/Visual_presentation.jpg)

Security Best pratice which should be followed :-
1.Used variables for AMI and tags
  To avoid typos and ensure consistency across resources.
  
2.Deployed EC2 in a private subnet with Security Group
  EC2 is accessible only within the VPC, not exposed to the internet.

3.Attached IAM Role to EC2 instance
  Access to S3 without hardcoded credentials, using least privilege (read-only access).

4.Enabled S3 versioning with block public access
  Supports fast rollback in case of failure or accidental changes.As without public access onone can access the S3 from internet reducing the surface of attack


  
    
