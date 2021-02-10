variable "secret" {
  type = string
}
variable "access" {
  type = string
}

provider "aws" {
   access_key =  var.access
   secret_key = var.secret
   region = var.region
}

resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "MY_VPC"
  }
}

resource "aws_subnet" "my_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  //map_customer_owned_ip_on_launch = true
  depends_on = [aws_vpc.my_vpc]
  tags = {
    Name = "MY_SUBNET"
  }
}

resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "MY_ROUTE_TABLE"
  }
}

resource "aws_route_table_association" "association" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_internet_gateway" "my_gw" {
  vpc_id = aws_vpc.my_vpc.id
depends_on = [aws_vpc.my_vpc]
  tags = {
    Name = "MY_GW"
  }
}

resource "aws_route" "r" {
  route_table_id            = aws_route_table.my_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.my_gw.id
  depends_on                = [aws_route_table.my_route_table]
}

resource "aws_security_group" "my_security_group" {
  name        = "my_security_group"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 ingress {
    description = "TLS from VPC"
    from_port   = 8080
    to_port     = 8080
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
    Name = "MY_SECURITY_GROUP"
  }
}

resource "tls_private_key" "my_private_key" {
  algorithm   = "RSA"
}

resource "aws_key_pair" "my_pub_key" {
  key_name   = "my_private_key"
  public_key = tls_private_key.my_private_key.public_key_openssh
}

resource "local_file" "my_private_key" {
    content     =  tls_private_key.my_private_key.private_key_pem
    filename = "my_private_key.pem"
}
/*
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self"]
}
*/
resource "aws_instance" "web" {
  ami           = "ami-0996d3051b72b5b2c"
  instance_type = "t2.micro"

  tags = {
    Name = "WEB"
  }
  count = 1
  subnet_id = aws_subnet.my_subnet.id
  key_name = "my_private_key"
  associate_public_ip_address = true
  security_groups = [aws_security_group.my_security_group.id]
  
   connection {
    type = "ssh"
    host = aws_instance.web[0].public_ip
    user = "ec2-user"
    private_key = tls_private_key.my_private_key.private_key_pem
    }
 
  provisioner "remote-exec" {
    connection {
    type = "ssh"
    host = aws_instance.web[0].public_ip
    user = "ec2-user"
    private_key = tls_private_key.my_private_key.private_key_pem
    }

    inline = [
      "sudo apt-get update",
		  "sudo apt-get install -y apache2",
		  "sudo systemctl start apache2",
		  "sudo systemctl enable apache2",
      "echo <h1>Deployed via Terraform</h1> | sudo tee /var/www/html/index.html",
    ]
  }
}

resource "aws_ebs_volume" "ebs_volume" {
  availability_zone = aws_instance.web[0].availability_zone
  size              = 1

  tags = {
    Name = "EBS_VOLUME"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  depends_on = [aws_ebs_volume.ebs_volume]
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs_volume.id
  instance_id = aws_instance.web[0].id
  force_detach = true
}

resource "null_resource" "nullmount" {
   depends_on = [aws_volume_attachment.ebs_att]
   connection {
    type = "ssh"
    host = aws_instance.web[0].public_ip
    user = "ec2-user"
    private_key = tls_private_key.my_private_key.private_key_pem
    }
 
  provisioner "remote-exec" {
    inline = [
      "df -h .",
      "lsblk",//The above command will list the disk you attached to your instance.
      "sudo file -s /dev/xvdf",//heck if the volume has any data
      "sudo mkfs.ext4 /dev/xvdh",
      "sudo mount /dev/xvdh var/www/html",
      "cd /var/www/html",
      "df -h .",//check the disk space for confirming the volume mount
      "sudo git clone https://github.com/shraddhaL/web-server.git  /var/www/html",
    ]
  }
}

locals{
      s3_origin_id = "s3-origin"
}

resource "aws_s3_bucket" "s3-bucketxcvcbvvcbx" {
  bucket = "s3-bucketxcvcbvvcbx"
  acl    = "public-read-write"
  //region = "us-east-2"

  versioning{
    enabled = true
  }

  tags = {
    Name        = "s3-bucketxcvcbvvcbx"
    Environment = "Prod"
  }

  provisioner "local-exec" {
    command = "git clone https://github.com/shraddhaL/web-server.git web-server"
 }
}

resource "aws_s3_bucket_public_access_block" "example" {
  depends_on = [aws_s3_bucket.s3-bucketxcvcbvvcbx]
  bucket = "s3-bucketxcvcbvvcbx"
  block_public_acls   = false
  block_public_policy = false
}

resource "aws_s3_bucket_object" "object" {
  depends_on = [aws_s3_bucket.s3-bucketxcvcbvvcbx]
  bucket = "s3-bucketxcvcbvvcbx"
  acl    = "public-read-write"
  key    = "image.png"
  source = "web-server/image.png"
}

resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  depends_on = [aws_s3_bucket_object.object]
  origin {
    domain_name = aws_s3_bucket.s3-bucketxcvcbvvcbx.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }
  enabled             = true
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

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

resource "null_resource" "Write_Image" {
    depends_on = [aws_cloudfront_distribution.cloudfront_distribution]
    connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.my_private_key.private_key_pem
    host     = aws_instance.web[0].public_ip
     }
  provisioner "remote-exec" {
        inline = [
            "sudo su << EOF",
                    "echo \"<img src='http://${aws_cloudfront_distribution.cloudfront_distribution.domain_name}/${aws_s3_bucket_object.object.key}' width='300' height='380'>\" >>/var/www/html/index.html",
                    "echo \"</body>\" >>/var/www/html/index.html",
                    "echo \"</html>\" >>/var/www/html/index.html",
                    "EOF",    
        ]
  }

}

#success message and storing the result in a file
resource "null_resource" "result" {
    depends_on = [null_resource.nullmount]
    provisioner "local-exec" {
    command = "echo The website has been deployed successfully and >> result.txt  && echo the IP of the website is  ${aws_instance.web[0].public_ip} >>result.txt"
  }
}

resource "null_resource" "running_the_website" {
    depends_on = [null_resource.Write_Image]

    provisioner "local-exec" {
    command = "start chrome ${aws_instance.web[0].public_ip}"
  }
}
