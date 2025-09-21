##################################
# Route53 Hosted Zone (per environment)
##################################

resource "aws_route53_zone" "environment" {
	name = "${var.environment}.${var.domain_name}"

	tags = {
		Environment = var.environment
		Project     = var.project_name
		ManagedBy   = "terraform"
	}
}

