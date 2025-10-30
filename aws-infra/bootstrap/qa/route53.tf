##################################
# Route53 Hosted Zone (per environment)
##################################

resource "aws_route53_zone" "environment" {
  name = "${var.environment}.${var.domain_name}"

  tags = local.merged_tags
}

##################################
# Elastic IP for edge host (public)
##################################

resource "aws_eip" "edge" {
  domain = "vpc"

  tags = merge(local.merged_tags, {
    Name = "${var.project_name}-${var.environment}-edge-eip"
  })
}

##################################
# Primary edge record / edge host public record (for reverse proxy & ACME)
##################################

resource "aws_route53_record" "edge_primary" {
  zone_id = aws_route53_zone.environment.zone_id
  name    = "edge.${aws_route53_zone.environment.name}" # edge.dev.uselayered.com
  type    = "A"
  ttl     = 300
  records = [aws_eip.edge.public_ip]
}

##################################
# PUBLIC record for GitHub Actions to push images
##################################

resource "aws_route53_record" "registry_public" {
  zone_id = aws_route53_zone.environment.zone_id
  name    = "registry.${aws_route53_zone.environment.name}" # registry.dev.uselayered.com
  type    = "A"
  ttl     = 300
  records = [aws_eip.edge.public_ip]
}

##################################
# PRIVATE record for internal VPC services to pull images
##################################

resource "aws_route53_record" "registry_private" {
  zone_id = aws_route53_zone.environment.zone_id
  name    = "registry.internal.${aws_route53_zone.environment.name}" # registry.internal.dev.uselayered.com
  type    = "A"
  ttl     = 300
  records = [var.edge_private_ip]
}

##################################
# PUBLIC record for Kibana UI (accessed via Caddy on Edge VM)
##################################

resource "aws_route53_record" "kibana" {
  zone_id = aws_route53_zone.environment.zone_id
  name    = "kibana.${aws_route53_zone.environment.name}" # kibana.dev.uselayered.com
  type    = "A"
  ttl     = 300
  records = [aws_eip.edge.public_ip]
}
