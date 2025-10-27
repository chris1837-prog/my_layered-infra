# ADR 0001 – Why Caddy over Nginx for Reverse Proxy

**Status:** Accepted

## Context
The team needed a **reverse proxy** to handle TLS termination, load balancing, and routing between microservices and web apps.  
Nginx and Traefik were considered standard options, but Nginx requires manual certificate management (e.g., certbot) and complex configuration syntax.  
With a small engineering team and an emphasis on rapid iteration and local development parity, ease of setup and maintenance were critical.  

## Decision
We selected **Caddy** as the reverse proxy.  
Caddy automatically provisions and renews Let’s Encrypt certificates, removing the need for certbot or CRON jobs.  
It provides a human-readable configuration file (`Caddyfile`) and supports modern protocols (HTTP/2, HTTP/3 QUIC) out of the box.  
Configuration changes can be applied dynamically without downtime, improving developer velocity.  

Caddy’s focus on simplicity and security aligns with our “secure-by-default” philosophy and developer-centric workflows.  
While Nginx offers greater tunability and plugin support, those features exceed our current needs.

## Consequences
Caddy makes HTTPS and routing **“just work”** with minimal maintenance, ideal for small teams and containerized environments.  
- **Positive:** Simplified configuration, automatic HTTPS, faster onboarding, less operational overhead.  
- **Negative:** Smaller ecosystem and fewer enterprise modules than Nginx.  
- **Trade-off:** Sacrifices advanced tuning in favor of simplicity and automation is an acceptable trade for our current scale.
