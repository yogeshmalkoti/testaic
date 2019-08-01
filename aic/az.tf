# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "aicvpc" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "${var.tag}"
  }
}


# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "aicgw" {
  vpc_id = "${aws_vpc.aicvpc.id}"

  tags = {
  Name = "${var.tag}"
  }
}

#resource "aws_nat_gateway" "gw" {
#  //other arguments

#  depends_on = ["aws_internet_gateway.aicgw"]
#}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.aicvpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.aicgw.id}"

}


# Create a subnet to launch our instances into
resource "aws_subnet" "aicsubnet" {
  count                   = "${length(var.private_subnet)}"
  vpc_id                  = "${aws_vpc.aicvpc.id}"
  cidr_block              = "${var.private_subnet[count.index]}"
  availability_zone       = var.aws_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
  Name = "${var.tag}"
  }
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "aicsgelb" {
  name        = "aic_sg_elb"
  description = "sg for elb"
  vpc_id      = "${aws_vpc.aicvpc.id}"

  tags = {
  Name = "${var.tag}"
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "aicsg" {
  name        = "aic_sg_group"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.aicvpc.id}"

  tags = {
  Name = "${var.tag}"
  }

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "aicelb" {
  name = "aic-elb"

  security_groups = ["${aws_security_group.aicsgelb.id}"]
  instances       = setunion("${aws_instance.aicweb.*.id}", "${aws_instance.aicweb1.*.id}")
  subnets         = "${data.aws_subnet_ids.aicsubnet.ids}"

  tags = {
  Name = "${var.tag}"
  }

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

    health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:80"
    interval            = 30
  }

}

#####################################################################################

######### create Policy ##################

resource "aws_iam_policy" "aicpolicy" {
  name        = "aicpolicy"
  path        = "/"
  description = "My test policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "*"
        }
    ]
}
EOF
}

############ create role ######

resource "aws_iam_role" "aicrole1" {
  name = "aicrole1"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_policy_attachment" "attachaic" {
  name       = "attachaic"
  roles      = ["${aws_iam_role.aicrole1.name}"]
  policy_arn = "${aws_iam_policy.aicpolicy.arn}"
}

resource "aws_iam_instance_profile" "aicprofile" {
  name  = "aicprofile"
  roles = ["${aws_iam_role.aicrole1.name}"]
}


#####################################################################################

data "aws_subnet_ids" "aicsubnet" {
  vpc_id = "${aws_vpc.aicvpc.id}"
  filter {
    name   = "tag:Name"
    values = ["aic"]
  }
  depends_on = ["aws_subnet.aicsubnet", "aws_vpc.aicvpc"]


}




#####################################################################################


resource "aws_instance" "aicweb" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ec2-user"
    host = "${self.public_ip}"
    # The connection will use the local SSH agent for authentication.
    password = ""
    private_key = "${file("/home/ec2-user/jumpkeypair.pem")}"


    }
  count         = length(var.private_subnet)
  instance_type = "t2.micro"


  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, var.aws_region)}"
  iam_instance_profile = "${aws_iam_instance_profile.aicprofile.name}"

  # The name of our SSH keypair we created above.
  key_name = "jumpkeypair"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.aicsg.id}"]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id             = "${tolist(data.aws_subnet_ids.aicsubnet.ids)[count.index]}"
  depends_on = ["aws_subnet.aicsubnet", "aws_vpc.aicvpc"]


######################################



  provisioner "file" {
    source      = "getdetail.sh"
    destination = "/tmp/getdetail.sh"
  }

#  provisioner "file" {
#    source      = "index.html"
#    destination = "/tmp/index.html"
#  }




##########################################


  user_data = <<-EOF
      #! /bin/bash
      sudo yum -y install httpd
      sudo yum -y install automake fuse fuse-devel gcc-c++ git libcurl-devel libxml2-devel make openssl-devel
      git clone https://github.com/s3fs-fuse/s3fs-fuse.git
      cd s3fs-fuse; ./autogen.sh;./configure --prefix=/usr --with-openssl
      sudo make install
      which s3fs
      sudo mkdir /var/www/html/aicbucket
      sudo sed -i s/SELINUX=enforcing/SELINUX=disable/g /etc/selinux/config
      sudo setenforce 0
      sudo usermod -G 'ec2-user' apache
      sudo chmod 777 /usr/share/httpd/noindex/index.html
      sudo chmod a+x /tmp/getdetail.sh
      sudo /tmp/getdetail.sh > /usr/share/httpd/noindex/index.html
      sudo chmod a+r /usr/share/httpd/noindex/index.html
      sudo service httpd start
      sudo nohup s3fs -f -d  aics3 -o use_cache=/tmp -o allow_other -o uid=1000 -o mp_umask=002 -o multireq_max=5 -o endpoint=ap-southeast-1 -o del_cache -o iam_role /var/www/html/aicbucket &
        EOF

#####################################################################################
}

resource "aws_instance" "aicweb1" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ec2-user"
    host = "${self.public_ip}"
    # The connection will use the local SSH agent for authentication.
    password = ""
    private_key = "${file("/home/ec2-user/jumpkeypair.pem")}"


    }
  count         = length(var.private_subnet)
  instance_type = "t2.micro"


  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, var.aws_region)}"
  iam_instance_profile = "${aws_iam_instance_profile.aicprofile.name}"

  # The name of our SSH keypair we created above.
  key_name = "jumpkeypair"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.aicsg.id}"]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id             = "${tolist(data.aws_subnet_ids.aicsubnet.ids)[count.index]}"
  depends_on = ["aws_subnet.aicsubnet", "aws_vpc.aicvpc"]


######################################



  provisioner "file" {
    source      = "getdetail.sh"
    destination = "/tmp/getdetail.sh"
  }

#  provisioner "file" {
#    source      = "index.html"
#    destination = "/tmp/index.html"
#  }




##########################################


  user_data = <<-EOF
      #! /bin/bash
      sudo yum -y install httpd
      sudo yum -y install automake fuse fuse-devel gcc-c++ git libcurl-devel libxml2-devel make openssl-devel
      git clone https://github.com/s3fs-fuse/s3fs-fuse.git
      cd s3fs-fuse; ./autogen.sh;./configure --prefix=/usr --with-openssl
      sudo make install
      which s3fs
      sudo mkdir /var/www/html/aicbucket
      sudo sed -i s/SELINUX=enforcing/SELINUX=disable/g /etc/selinux/config
      sudo setenforce 0
      sudo usermod -G 'ec2-user' apache
      sudo chmod 777 /usr/share/httpd/noindex/index.html
      sudo chmod a+x /tmp/getdetail.sh
      sudo /tmp/getdetail.sh > /usr/share/httpd/noindex/index.html
      sudo chmod a+r /usr/share/httpd/noindex/index.html
      sudo service httpd start
      sudo nohup s3fs -f -d  aics3 -o use_cache=/tmp -o allow_other -o uid=1000 -o mp_umask=002 -o multireq_max=5 -o endpoint=ap-southeast-1 -o del_cache -o iam_role /var/www/html/aicbucket &
        EOF



}
