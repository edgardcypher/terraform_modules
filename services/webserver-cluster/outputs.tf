# output "public_ip" {
#     value = aws_instance.example.public_ip
#     description = "the public ip of the web server"
# }
output "alb_dns_name" {
    value = aws_lb.app_lb.dns_name
    description = "The domain name if the load balancer"
}
output "asg_name" {
  value       = aws_autoscaling_group.example_autoscaling.name
  description = "The name of the Auto Scaling Group"
}

output "alb_security_group_id" {
  value       = aws_security_group.sec_group_alb.id
  description = "The ID of the Security Group attached to the ALB"
}