
# To create a create the declaration is
// resource "<PROVIDER>_<TYPE>" "<NAME>" {
//  [CONFIG …]
// }
# Where PROVIDER is the name of a provider (e.g., aws), TYPE is the type of resources to create 
# in that provider (e.g., instance), NAME is an identifier you can use throughout the Terraform 
# code to refer to this resource (e.g., example), and CONFIG consists of one or more arguments 
# that are specific to that resource (e.g., ami = "ami-0c55b159cbfafe1f0"). For the aws_instance resource.

# for this provider we create a server resource EC2 with the name example
# the type of instance is t2.micro and it will run an AMI .

#the bash script referred on user_data will run a simple web server that always return the text "Hello, World"
/*
This is a bash script that writes the text “Hello, World” into index.html and runs a web server on port 8080 
using busybox (which is installed by default on Ubuntu) to serve that file at the URL “/”. We wrap the busybox 
command with nohup to ensure the web server keeps running even after this script exits and put an & at the end of the 
command so the web server runs in a background process and the script can exit rather than being blocked forever by the web server.

How do you get the EC2 Instance to run this script? Normally, instead of using an empty Ubuntu AMI, you would use a tool like 
Packer to create a custom AMI that has the web server installed on it. But again, in the interest of keeping this example simple, 
we’re going to run the script above as part of the EC2 Instance’s User Data, which AWS will execute when the instance is booting:
**/

# resource "aws_instance" "example" {
#     ami ="ami-0c6de836734de3280"
#     instance_type = "t2.micro"
#     vpc_security_group_ids = [aws_security_group.sec-group-instance.id]

#     user_data = <<-EOF
#                 #!/bin/bash
#                 echo "Hello, World" > index.html
#                 nohup busybox httpd -f -p "${var.server_port}" &
#                 EOF

#     tags = {
#         Name = "terraform-example"
#     }
# }

# below we create a new aws_security_group because by default 
# AWS does not allow any incoming or outgoing traffic from an EC2 instance
# The CIDR block 0.0.0.0/0 is an IP address range that includes all possible IP addresses,
# so this security group allows incoming requests on port 8080 from any IP

resource "aws_security_group" "ec2_instance_sg" {
    name = "${var.cluster_name}_instance"
}

# below i define separe aws sec grp rule for Inbound HTTP from anywhere
resource "aws_security_group_rule" "allow_tcp_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.ec2_instance_sg.id

  from_port   = var.server_port
  to_port     = var.server_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

# this file is used to declare or configure a new provider
# here the provider is AWS but it could be AZURE or google cloud
# we comment the provider because it needs to be declared at the root module
# provider "aws" {
#     #infra will be deploy in the us-east-2 region
#     region = "us-east-2"
# }
# ---------------------------------------------------------------------------------------------------------------------
# GET THE LIST OF AVAILABILITY ZONES IN THE CURRENT REGION
# Every AWS account has slightly different availability zones in each region. For example, one account might have
# us-east-1a, us-east-1b, and us-east-1c, while another will have us-east-1a, us-east-1b, and us-east-1d. This resource
# queries AWS to fetch the list for the current account and region.
# ---------------------------------------------------------------------------------------------------------------------
data "aws_availability_zones" "all_AZ" {}

# below we declare terraform data source to read the state file of mysql rds from the s3 bucket. doing this 
# we can pull in all mysql database's state data to be used anywhere in the config file  
data "terraform_remote_state" "db" {
    backend = "s3"
    config = {
        bucket  = var.db_remote_state_bucket # name of s3 bucket
        key     = var.db_remote_state_key
        region  = "us-east-2"
    }
}

# To get a list of VPC available to this aws account
data "aws_vpc" "vpc_info"{
    default = true # this filter will directs terraform to look up for the default VPC in the aws account

}

# to look up all available subnets within a VPC
 data "aws_subnets" "subnets_info" {
     filter {
         name = "vpc-id"
         values = [data.aws_vpc.vpc_info.id]
     }
 }

# below we will be creating a launch configuration resource that will be
# used by a auto scaling group to scale cluster. The launch configuration will configure
# EC2 that will be used by cluster. The lifecycle in the setting below tells us that 
# we need to create a new ec2 instance before delete old one.

resource "aws_launch_configuration" "launch_conf_ec2" {
    image_id ="ami-0c6de836734de3280"
    instance_type = var.instance_type
    security_groups = [aws_security_group.ec2_instance_sg.id]

    user_data = templatefile("${path.module}/user-data.sh",{
        server_port = var.server_port
        db_address  = data.terraform_remote_state.db.outputs.address
        db_port     = data.terraform_remote_state.db.outputs.port
    })

    # Required when using a launch configuration with an ASG. this will allow to create a new launch conf everytime a parameter is changed 
    # and then delete the old one
    lifecycle {
    create_before_destroy = true
  }
}

# below we wil create an auto scaling group that will use the launch configuration
# above.This ASG will run between 2 and 10 EC2 instances but 2 will be default in the inital launch.
# each instance will be tagged with the name "terraform-asg-example". we add availability_zones parameter to
#specifies into which AZ the EC2 instances should be deployed

resource "aws_autoscaling_group" "example_autoscaling" {
  launch_configuration = aws_launch_configuration.launch_conf_ec2.id
#   availability_zones = data.aws_availability_zones.all_AZ.names
  vpc_zone_identifier = data.aws_subnets.subnets_info.ids

  min_size = var.min_size
  max_size = var.max_size

  # below we tell ASG to register each instance in the LB and also add health check type to be ELB instead of EC2.
  # The “ELB” health check is more robust, because it instructs the ASG to use the target group’s health check 
  #to determine whether an Instance is healthy and to automatically replace Instances if the target group reports 
  #them as unhealthy
#   load_balancers    = [aws_elb.classic_elb.name]
  health_check_type = "ELB"
  target_group_arns = [aws_lb_target_group.target_grp.arn]

  tag {
    key                 = "instance-name"
    value               = "${var.cluster_name}-asg"
    propagate_at_launch = true
  }
}

# below we will create a load balancer that will distribute traffic accross our ec2 server 
# and also give client users a single Ip address where the request will be sent. the IP address will be
# the address of the load balancer server. AWS handles automatically the scalability and availability of ELB
# in different AZ based on the traffics and also failover.

# resource "aws_elb" "classic_elb" {
#     name = "${var.cluster_name}-ELB"
#     load_balancer_type = "application"
#     subnets            = data.aws_subnets.subnets_info.ids # this parameter configure the load balancer to use all the subnets in the default VPC.
#     availability_zones      = data.aws_availability_zones.all_AZ.names
#     security_groups         = [aws_security_group.sec_group_elb.id]
    
#     # below we add a health check to periodically check the health of
#     # the EC2, if an ec2 is unhealthy the lb balancer will periodically stop
#     # routing the traffic to it. below we add a LB health check where LB will send an HTTP
#     #request every 30s to "/" URL of each ec2. LB will mark the ec2 as healthy if it responds with 200 OK twice and unhealthy otherwise.
#     health_check {
#         target                  = "HTTP:${var.server_port}/"
#         interval                = 30
#         timeout                 = 3
#         healthy_threshold       = 2
#         unhealthy_threshold     = 2
#     }

#     # this adds a listener for incoming HTTP requests.We are telling classic LB
#     # to listen any HTTP requests on port 80 and then route them to the port used
#     # by the instances in the ASG    
#     listener {
#         lb_port           = var.elb_port
#         lb_protocol       = "http"
#         instance_port     = var.server_port
#         instance_protocol = "http"
#     }
# }

resource "aws_lb" "app_lb" {
  name               = "terraform-app-lb"
  load_balancer_type = "application"
  security_groups         = [aws_security_group.sec_group_alb.id]
  subnets            = data.aws_subnets.subnets_info.ids # this parameter configure the load balancer to use all the subnets in the default VPC.
}

# below we create a new security group for the classic Lb since
# load balancer server as well as EC2 instances does not allow by default any inbound or outbound requests
resource "aws_security_group" "sec_group_alb" {
    name = "${var.cluster_name}_alb"
}

# below i define separe aws sec grp rule for Inbound HTTP from anywhere
resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.sec_group_alb.id

  from_port   = local.http_port
  to_port     = local.http_port
  protocol    = local.tcp_protocol
  cidr_blocks = local.all_ips
}

# below i define separe aws sec grp rule for all outbound request, this is needed for health checks of LB
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.sec_group_alb.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}




# below we will create a target group for the auto-scaling group.
/*This target group will health check your Instances by periodically sending an HTTP request 
to each Instance and will consider the Instance “healthy” only if the Instance returns a response 
that matches the configured matcher (e.g., you can configure a matcher to look for a 200 OK response). 
If an Instance fails to respond, perhaps because that Instance has gone down or is overloaded, it will be marked 
as “unhealthy,” and the target group will automatically stop sending traffic to it to minimize disruption for your users.*/
resource "aws_lb_target_group" "target_grp" {
    name    = "terraform-target-grp"
    port    = var.server_port
    protocol= "HTTP"
    vpc_id  = data.aws_vpc.vpc_info.id

    health_check {
        path                = "/"
        protocol            = "HTTP"
        matcher             = "200"
        interval            = 15
        timeout             = 3
        healthy_threshold   = 2
        unhealthy_threshold = 2
    }       
}

# below we will create a listener for the load balancer.
# This listener configures the ALB to listen on the default HTTP port, port 80, use HTTP as the protocol, and 
#send a simple 404 page as the default response for requests that don’t match any listener rules.
resource "aws_lb_listener" "http_listener" {
    load_balancer_arn   = aws_lb.app_lb.arn #the listener will use the Alb defined previously
    port                = local.http_port
    protocol            = "HTTP"

    default_action {
        type    = "fixed-response"

        fixed_response {
            content_type    = "text/plain"
            message_body    = "404: page not found"
            status_code     = 404
        }
    }
}


# below we will define the listener rule. the rule defines will send request 
# that match any path to the target group that contains the ASG
resource "aws_lb_listener_rule" "listener_rule" {
    listener_arn = aws_lb_listener.http_listener.arn # the arn of the listener we defined earlier
    priority     = 100

    condition {
        path_pattern {
            values = ["*"]
        }
    }

    action {
        type    = "forward"
        target_group_arn = aws_lb_target_group.target_grp.arn
    }
}

# below we define some local variable module which we don't want to overrider by setting in the variable.tf file
locals {
    http_port       = 80
    any_port        = 0
    any_protocol    = "-1"
    tcp_protocol    = "tcp"
    all_ips         = ["0.0.0.0/0"]
}