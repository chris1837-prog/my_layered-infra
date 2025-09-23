########################################
# Budget + SNS Setup
########################################

resource "aws_sns_topic" "budget_alerts" {
  name = var.topic_name
  tags = var.tags
}

# Create email subscriptions (must be confirmed by recipients)
resource "aws_sns_topic_subscription" "email_subs" {
  count     = length(var.emails)
  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = var.emails[count.index]
}

resource "aws_budgets_budget" "this" {
  name         = var.name
  budget_type  = "COST"
  limit_amount = var.amount_usd
  limit_unit   = "USD"
  time_unit    = var.time_unit

  # Add filters if provided
  dynamic "cost_filter" {
    for_each = var.cost_filters
    content {
      name   = cost_filter.key
      values = cost_filter.value
    }
  }

  # Notifications for each threshold
  dynamic "notification" {
    for_each = toset([for t in var.thresholds : tostring(t)])
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = tonumber(notification.key)
      threshold_type             = "PERCENTAGE"
      notification_type          = var.notification_type
      subscriber_sns_topic_arns  = [aws_sns_topic.budget_alerts.arn]
      subscriber_email_addresses = var.emails
    }
  }

  tags = var.tags
}