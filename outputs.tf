output "alb_dns_name" {
    description = "Output the value of the DNS name of the ALB."
    value = aws_lb.alb.dns_name
}