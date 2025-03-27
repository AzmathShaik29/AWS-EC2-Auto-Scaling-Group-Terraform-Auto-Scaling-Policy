output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.my_new_vpc.id
  
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.my_application_load_balancer.dns_name
  
}

output "asg_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.my_asg.name
  
}