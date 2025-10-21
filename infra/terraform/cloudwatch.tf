resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ec2/${var.app_name}"
  retention_in_days = var.log_retention_days
  tags = { Name = "${var.app_name}-logs" }
}

resource "aws_cloudwatch_dashboard" "app" {
  dashboard_name = "${var.app_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        "type":"metric","x":0,"y":0,"width":12,"height":6,
        "properties":{
          "metrics":[["AWS/EC2","CPUUtilization","InstanceId",aws_instance.app.id,{"stat":"Average","label":"CPU Avg"}],["...",{"stat":"Maximum","label":"CPU Max"}]],
          "view":"timeSeries","stacked":false,"period":300,"stat":"Average","region":var.aws_region,"title":"EC2 CPU Utilization",
          "yAxis":{"left":{"min":0,"max":100}}
        }
      },
      {
        "type":"metric","x":12,"y":0,"width":12,"height":6,
        "properties":{
          "metrics":[["CWAgent","MEM_USED","InstanceId",aws_instance.app.id,{"stat":"Average","label":"Memory %"}]],
          "view":"timeSeries","stacked":false,"period":300,"stat":"Average","region":var.aws_region,"title":"Memory Usage %",
          "yAxis":{"left":{"min":0,"max":100}}
        }
      },
      {
        "type":"metric","x":0,"y":6,"width":8,"height":6,
        "properties":{
          "metrics":[["CWAgent","DISK_USED","InstanceId",aws_instance.app.id,{"stat":"Average","label":"Disk %"}]],
          "view":"timeSeries","stacked":false,"period":300,"stat":"Average","region":var.aws_region,"title":"Disk Usage %",
          "yAxis":{"left":{"min":0,"max":100}}
        }
      }
    ]
  })
}

resource "aws_sns_topic" "alerts" {
  name = "${var.app_name}-alerts"
  tags = { Name = "${var.app_name}-alerts-topic" }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.app_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  dimensions = { InstanceId = aws_instance.app.id }
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.app_name}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MEM_USED"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  treat_missing_data  = "breaching"
  dimensions = { InstanceId = aws_instance.app.id }
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}
