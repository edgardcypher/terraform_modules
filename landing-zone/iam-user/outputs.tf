output "iam_user_arn" {
    value   = aws_iam_user.an_iam_user.arn
    description = "The ARN of the created IAM user"
}