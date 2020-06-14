provider "aws" {
  region     = "ap-south-1"
  profile    = "juned"
}
//creating key
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41 email@example.com"
}

//creating security groups
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-15968b7d"


 ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "ssh"
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

  tags = {
    Name = "allow_tls"
  }
}



//
//instance

resource "aws_instance" "web" {
depends_on = [
	      aws_security_group.allow_tls
		]


  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "mykey11"
  security_groups = [ "allow_tls" ]
  tags={ 
Name = "webos1"
}
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/juned/Downloads/mykey11.pem")
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  

}

//




//
//s3
resource "aws_s3_bucket" "webucket" {
  bucket = "webucket1234"
  force_destroy = true
  acl    = "public-read"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "MYBUCKETPOLICY",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::webucket1234/*"
    }
  ]
}
POLICY
 }
resource "aws_s3_bucket_object" "object" {
  bucket = "webucket1234"
  key    = "cloud.png"
  source = "C:/Users/juned/Pictures/Screenshots/cloud.png"
  etag = "C:/Users/juned/Pictures/Screenshots/cloud.png"
depends_on = [aws_s3_bucket.webucket,
		]
}










//volume

resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "autoebs"
  }
}




//volume attach 
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}

//mounting

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/juned/Downloads/mykey11.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/juned171/hybrid_cloud.git /var/www/html/"
    ]
  }
}







//cloudfront

  

locals {
  s3_origin_id = "myS3Origin"
}

   resource "aws_cloudfront_distribution" "hybridcld" {
   origin {
         domain_name = "${aws_s3_bucket.webucket.bucket_regional_domain_name}"
         origin_id   = "${local.s3_origin_id}"
  
 custom_origin_config {

         http_port = 80
         https_port = 80
         origin_protocol_policy = "match-viewer"
         origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
      }
         enabled = true

 default_cache_behavior {
        
         allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
         cached_methods   = ["GET", "HEAD"]
         target_origin_id = "${local.s3_origin_id}"

 forwarded_values {

       query_string = false
       
 cookies {
          forward = "none"
         }
    }
          
          viewer_protocol_policy = "allow-all"
          min_ttl                = 0
          default_ttl            = 3600
          max_ttl                = 86400

}
  restrictions {
         geo_restriction {
           restriction_type = "none"
          }
     }
 viewer_certificate {
       cloudfront_default_certificate = true
       }
}



//


resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}
}






resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote3,
  ]

	provisioner "local-exec" {
	    command = "start  chrome  ${aws_instance.web.public_ip}"
  	}
}
