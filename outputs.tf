# Output the DNS name of the ALB
output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}