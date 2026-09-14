resource "aws_launch_template" "wordpress-ec2" {
  name_prefix   = "wordpress-ec2-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  user_data= <<EOT
    #!/bin/bash
    # Update der Paketliste und Installation von Apache
    sudo yum update -y
    sudo yum install -y httpd

    # Starten des Apache-Webservers Test
    sudo systemctl start httpd

    # Aktivieren des Apache-Webservers beim Systemstart
    sudo systemctl enable httpd
                    
    # Erstellen der "index.html"-Datei
    echo "<html><head><title>Hello World</title></head><body><h1>Hello World</h1><p>This is a simple webpage served by Apache.</p></body></html>" | sudo tee /var/www/html/index.html >/dev/null
  EOT

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.wordpress-sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "wordpress-ec2"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_ami" "al2023" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "al2023-ami-*-x86_64",
    ]
  }

  owners = [
    "amazon",
  ]
}

resource "aws_security_group" "wordpress-sg" {
  name_prefix = "wordpress-sg-"
  vpc_id      = aws_vpc.vpc-nwl-346.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

#   ingress {
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_autoscaling_group" "wordpress-asg" {
  desired_capacity     = 3
  max_size             = 5
  min_size             = 2
  vpc_zone_identifier  = [aws_subnet.snet-public-nwl-346.id]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  launch_template {
    id      = aws_launch_template.wordpress-ec2.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "wordpress-asg"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.wordpress-asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 80.0
  }
}

resource "aws_autoscaling_attachment" "wordpress-asg-lb" {
  autoscaling_group_name = aws_autoscaling_group.wordpress-asg.name
  lb_target_group_arn    = aws_lb_target_group.wordpress-http-tg.arn
}

resource "aws_lb" "wordpress-lb" {
  name               = "wordpress-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.wordpress-sg.id]
  subnets = [aws_subnet.snet-public-nwl-346.id, aws_subnet.snet-public-nwl-346b.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "wordpress-http-tg" {
  name        = "wordpress-http-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc-nwl-346.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "wordpress-http-lt" {
  load_balancer_arn = aws_lb.wordpress-lb.arn 
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress-http-tg.arn
  }
}
