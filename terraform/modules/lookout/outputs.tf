output "sns_topic_arn" {
  value = aws_sns_topic.anomaly_alerts.arn
}
output "lookout_role_arn" {
  value = aws_iam_role.lookout_role.arn
}
