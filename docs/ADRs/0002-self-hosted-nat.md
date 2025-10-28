# ADR 0002 – Why a Self-Hosted NAT Instance over AWS NAT Gateway

**Status:** Accepted

## Context
Private subnets in AWS required outbound internet access for updates and dependency downloads.  
AWS NAT Gateway is easy to operate but can become **10× more expensive** than self-hosting for moderate traffic patterns.  
It also provides limited visibility into network traffic and minimal options for customization or logging—both important for our security model.

## Decision
We deployed a **self-hosted NAT instance** by using our existing edge VM (the same one that runs Caddy and WireGuard) and simply enabling iptables forwarding on it to save costs, instead of AWS NAT Gateway.  
This approach reduces recurring costs and gives the team full control and observability.  
It allows:
- Detailed logging and custom monitoring (e.g., CloudWatch Agent, OS-level metrics)  
- Potential for caching or traffic shaping to optimize bandwidth  
- Hands-on ownership of routing and scaling decisions  
- Redundancy using Auto Scaling Groups for high availability  

While AWS NAT Gateway is more hands-off, our team values transparency and cost efficiency.

## Consequences
The self-hosted NAT saves cost and increases flexibility at the cost of some **maintenance and patching overhead**.  
- **Positive:** Cost reduction, fine-grained visibility, customizable security, hands-on network insight.  
- **Negative:** Manual management of updates, failover, and scaling.  
- **Trade-off:** Slightly higher operational burden in exchange for long-term cost control and technical learning—appropriate for a cost-conscious, capable engineering team.

