provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "my_new_vpc" {
    cidr_block = var.vpc_cidr
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "My new VPC"
    }
}

resource "aws_subnet" "public_subnet_1" {
    vpc_id = aws_vpc.my_new_vpc.id
    cidr_block = var.subnet_cidrs[0]
    availability_zone = var.availability_zones[0]
    map_public_ip_on_launch = true # this makes the subnet public
    tags = {
        Name = "Public subnet 1"
    }
}

resource "aws_subnet" "public_subnet_2" {
    vpc_id = aws_vpc.my_new_vpc.id
    cidr_block = var.subnet_cidrs[1]
    availability_zone = var.availability_zones[1]
    map_public_ip_on_launch = true # this makes the subnet public
    tags = {
        Name = "Public subnet 2"
    }
}

resource "aws_subnet" "public_subnet_3" {
    vpc_id = aws_vpc.my_new_vpc.id
    cidr_block = var.subnet_cidrs[2]
    availability_zone = var.availability_zones[2]
    map_public_ip_on_launch = true # this makes the subnet public
    tags = {
        Name = "Public subnet 3"
    }
}


# Internet gateway: to allow incoming internet traffic to reach the ALB
resource "aws_internet_gateway" "my_igw" {
    vpc_id = aws_vpc.my_new_vpc.id
    tags = {
        Name = "My IGW"
    }
}

# Public route table
resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.my_new_vpc.id
    # all the traffic should be routed to the internet gateway
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_igw.id
    }
    tags = {
        Name = "Public route table"
    }
    depends_on = [ aws_internet_gateway.my_igw ]
}

resource "aws_route_table_association" "public_subnet_1_association" {
    subnet_id      = aws_subnet.public_subnet_1.id
    route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
    subnet_id      = aws_subnet.public_subnet_2.id
    route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_3_association" {
    subnet_id      = aws_subnet.public_subnet_3.id
    route_table_id = aws_route_table.public_route_table.id
}

# Allocate Elastic IP address for the NAT gateway
resource "aws_eip" "my_eip" {
    domain = "vpc"
    depends_on = [ aws_internet_gateway.my_igw ]
}
# NAT gateway: to provide Internet access to EC2 instances
resource "aws_nat_gateway" "my_nat_gateway" {
    subnet_id     = aws_subnet.public_subnet_1.id
    allocation_id = aws_eip.my_eip.id
    tags = {
        Name = "My NAT Gateway"
    }
    depends_on = [ aws_internet_gateway.my_igw ]
}

resource "aws_security_group" "ec2_sg" {
    vpc_id = aws_vpc.my_new_vpc.id
    # Allow SSH from anywhere (adjust CIDR for security)
    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # Allow HTTP
    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        security_groups = [aws_security_group.alb_sg.id]
    }

    # Allow all outbound traffic
    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}
    
resource "aws_security_group" "alb_sg" {
    vpc_id = aws_vpc.my_new_vpc.id
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}

resource "aws_lb" "my_application_load_balancer" {
    name               = "my-application-load-balancer"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb_sg.id]
    subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id, aws_subnet.public_subnet_3.id]
    enable_cross_zone_load_balancing = true
    enable_deletion_protection = false
    tags = {
        Name = "My application load balancer"
    }
    depends_on = [ aws_internet_gateway.my_igw ]
}

resource "aws_lb_target_group" "my_target_group_terraform" {
    name     = "my-target-group-terraform"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.my_new_vpc.id
    target_type = "instance"
    health_check {
        path                = "/"
        protocol            = "HTTP"
        port                = "traffic-port"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 4
        interval            = 5
    }
    tags = {
        Name = "My target group Terraform"
    }
}

resource "aws_lb_listener" "my_listener" {
    load_balancer_arn = aws_lb.my_application_load_balancer.arn
    port              = "80"
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.my_target_group_terraform.arn
    }
}

# Define a launch template (Updated to assign Public IP)
resource "aws_launch_template" "my_launch_template" {
    name_prefix = "my_launch_template_"
    image_id = var.ami_id
    instance_type = var.instance_type
    key_name = var.key_name
   # vpc_security_group_ids = [ aws_security_group.ec2_sg.id ]

    network_interfaces {
        associate_public_ip_address = true  # Ensure public IP assignment
        security_groups = [aws_security_group.ec2_sg.id]
    }
    
    user_data = base64encode(<<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install -y nginx
            sudo systemctl start nginx
            sudo systemctl enable nginx
            echo "Welcome to the world of Terraform" > /var/www/html/index.html
            EOF
            )
}

# Define an Auto Scaling group (Updated to use Public Subnets to get Public IP for EC2 instances)
resource "aws_autoscaling_group" "my_asg" {
    vpc_zone_identifier = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id, aws_subnet.public_subnet_3.id]
    min_size = 1
    max_size = 3
    desired_capacity = 2

    # Associate with ALB target group
    target_group_arns = [aws_lb_target_group.my_target_group_terraform.arn]

    tag {
        key = "Name"
        value = "My ASG"
        propagate_at_launch = true
    }

    # Specify the launch template defined before
    launch_template {
        id = aws_launch_template.my_launch_template.id
        version = "$Latest"
    }
}

resource "aws_autoscaling_policy" "increase_ec2" {
    name                   = "increase-ec2"
    scaling_adjustment     = 1
    adjustment_type        = "ChangeInCapacity"
    cooldown               = 300
    autoscaling_group_name = aws_autoscaling_group.my_asg.name
    policy_type = "SimpleScaling"
    
}

resource "aws_autoscaling_policy" "reduce_ec2" {
    name                   = "reduce-ec2"
    scaling_adjustment     = -1
    adjustment_type        = "ChangeInCapacity"
    cooldown               = 300
    autoscaling_group_name = aws_autoscaling_group.my_asg.name
    policy_type = "SimpleScaling"
}

# Attach the Auto Scaling Group to the ALB target group
resource "aws_autoscaling_attachment" "my_asg_attachment" {
    autoscaling_group_name = aws_autoscaling_group.my_asg.id
    lb_target_group_arn = aws_lb_target_group.my_target_group_terraform.arn
}

resource "aws_cloudwatch_metric_alarm" "increase_ec2_alarm" {
  alarm_name                = "increase-ec2-alarm"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 120
  statistic                 = "Average"
  threshold                 = 70
  alarm_description         = "This metric monitors ec2 cpu utilization, if it goes above 70% for 2 periods it will trigger an alarm."
  insufficient_data_actions = []

 alarm_actions = [
      "${aws_autoscaling_policy.increase_ec2.arn}"
  ]
}

resource "aws_cloudwatch_metric_alarm" "reduce_ec2_alarm" {
  alarm_name                = "reduce-ec2-alarm"
  comparison_operator       = "LessThanOrEqualToThreshold"
  evaluation_periods        = 2
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 120
  statistic                 = "Average"
  threshold                 = 40
  alarm_description         = "This metric monitors ec2 cpu utilization, if it goes below 40% for 2 periods it will trigger an alarm."
  insufficient_data_actions = []

  alarm_actions = [
      "${aws_autoscaling_policy.reduce_ec2.arn}"
  ]
}
