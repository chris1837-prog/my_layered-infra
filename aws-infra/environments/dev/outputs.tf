########################################
# Outputs (DEV)
########################################

output "budget_dev_name" {
  description = "Budget name in DEV"
  value       = module.budget_dev.budget_name
}

output "budget_dev_topic_arn" {
  description = "SNS Topic ARN for DEV budget alerts"
  value       = module.budget_dev.sns_topic_arn
}

output "elk_vm_private_ip" {
  description = "The private IP address of the ELK virtual machine used for Logstash ingestion and Kibana proxying through the Edge."
  value       = aws_instance.obs_elk_vm.private_ip
}


output "generated_key" {
  description = "The generated key-pair for main.tf"
  value       = aws_key_pair.generated_key.key_name
}

output "app_domain" {
  description = "Public domain for the app (edge layer)"
  value       = module.edge.primary_domain
}