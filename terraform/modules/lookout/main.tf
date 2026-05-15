# SNS Topic
resource "aws_sns_topic" "anomaly_alerts" {
  name = "${var.project_name}-anomaly-alerts"
  tags = { Name = "${var.project_name}-anomaly-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.anomaly_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Lookout IAM role
resource "aws_iam_role" "lookout_role" {
  name = "${var.project_name}-lookout-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lookoutmetrics.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lookout_policy" {
  name = "${var.project_name}-lookout-policy"
  role = aws_iam_role.lookout_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:GetMetricData",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricStatistics",
        "sns:Publish"
      ]
      Resource = "*"
    }]
  })
}

# Lambda IAM role
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-anomaly-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cloudwatch:PutMetricData",
        "cloudwatch:GetMetricData",
        "sns:Publish",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "*"
    }]
  })
}

# Lambda function
resource "aws_lambda_function" "anomaly_handler" {
  filename         = "${path.module}/anomaly_handler.zip"
  function_name    = "${var.project_name}-anomaly-handler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "anomaly_handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  description      = "Auto-responds to SRE platform anomalies"

  environment {
    variables = {
      SNS_ARN     = aws_sns_topic.anomaly_alerts.arn
      ENVIRONMENT = var.environment
    }
  }

  tags = { Name = "${var.project_name}-anomaly-handler" }
}

# Allow SNS to invoke Lambda
resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.anomaly_handler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.anomaly_alerts.arn
}

# Subscribe Lambda to SNS
resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.anomaly_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.anomaly_handler.arn
}

# CloudWatch Alarm ? SNS for ErrorRate anomaly
resource "aws_cloudwatch_metric_alarm" "error_rate_anomaly" {
  alarm_name          = "${var.project_name}-error-rate-anomaly"
  alarm_description   = "ErrorRate anomaly detected"
  evaluation_periods  = 2
  threshold_metric_id = "ad1"
  comparison_operator = "GreaterThanUpperThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.anomaly_alerts.arn]

  metric_query {
    id          = "m1"
    return_data = true
    metric {
      namespace   = "SREPlatform/FlaskApp"
      metric_name = "ErrorRate"
      period      = 300
      stat        = "Average"
      dimensions = {
        Service     = "sre-platform"
        Environment = "dev"
      }
    }
  }

  metric_query {
    id          = "ad1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)"
    return_data = true
  }
}

# CloudWatch Alarm ? SNS for RequestCount anomaly
resource "aws_cloudwatch_metric_alarm" "request_count_anomaly" {
  alarm_name          = "${var.project_name}-request-count-anomaly"
  alarm_description   = "RequestCount anomaly detected"
  evaluation_periods  = 2
  threshold_metric_id = "ad1"
  comparison_operator = "GreaterThanUpperThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.anomaly_alerts.arn]

  metric_query {
    id          = "m1"
    return_data = true
    metric {
      namespace   = "SREPlatform/FlaskApp"
      metric_name = "RequestCount"
      period      = 300
      stat        = "Average"
      dimensions = {
        Service     = "sre-platform"
        Environment = "dev"
      }
    }
  }

  metric_query {
    id          = "ad1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)"
    return_data = true
  }
}
