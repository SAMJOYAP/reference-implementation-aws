output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "fluent_bit_role_arn" {
  description = "IAM role ARN for Fluent Bit"
  value       = aws_iam_role.fluent_bit.arn
}
