# Critical Security Events for Logging and Alerting

This document outlines critical security events that should be logged and monitored to detect potential threats across the infrastructure and application layers.

## 1. Infrastructure-Level Events

### 1.1. Failed SSH Logins

- **Description**: Multiple failed SSH login attempts from the same IP address may indicate a brute-force or dictionary attack.
- **Logging Context**:
| Field | Description | Example |
| :--- | :--- | :--- |
| `timestamp` | ISO 8601 timestamp | `2023-10-27T10:00:00Z` |
| `source_ip` | IP address of the client | `198.51.100.22` |
| `username` | The username attempted | `root` |
| `port` | The SSH port | `22` |
| `outcome` | `failure` | `failure` |
| `reason` | Reason for failure | `invalid_credentials` |

### 1.2. UFW Rule Changes

- **Description**: Unauthorized or unexpected changes to firewall rules can expose the system to external threats.
- **Logging Context**:
| Field | Description | Example |
| :--- | :--- | :--- |
| `timestamp` | ISO 8601 timestamp | `2023-10-27T10:05:00Z` |
| `user_id` | User who made the change | `admin` |
| `rule_change` | Description of the change | `ALLOW from 192.0.2.0/24` |
| `outcome` | `success` or `failure` | `success` |

### 1.3. Caddy TLS Errors

- **Description**: A spike in TLS handshake errors can indicate misconfigurations, expired certificates, or a potential Man-in-the-Middle (MitM) attack.
- **Logging Context**:
| Field | Description | Example |
| :--- | :--- | :--- |
| `timestamp` | ISO 8601 timestamp | `2023-10-27T10:10:00Z` |
| `source_ip` | IP address of the client | `203.0.113.10` |
| `server_name` | The requested server name (SNI) | `app.example.com` |
| `error_message` | The specific TLS error | `tls: handshake failure` |

### 1.4. AWS IAM Policy Changes

- **Description**: Unauthorized modifications to IAM roles or policies can lead to privilege escalation.
- **Logging Context**:
| Field | Description | Example |
| :--- | :--- | :--- |
| `timestamp` | ISO 8601 timestamp | `2023-10-27T10:15:00Z` |
| `user_arn` | ARN of the user/role making the change | `arn:aws:iam::123456789012:user/admin` |
| `policy_arn` | ARN of the policy being changed | `arn:aws:iam::123456789012:policy/AdminAccess` |
| `action` | The API action | `PutRolePolicy` |
| `source_ip` | IP address of the requestor | `198.51.100.5` |

### 1.5. AWS Security Group Modifications

- **Description**: Unexpected changes to security groups could expose services to unauthorized traffic.
- **Logging Context**:
| Field | Description | Example |
| :--- | :--- | :--- |
| `timestamp` | ISO 8601 timestamp | `2023-10-27T10:20:00Z` |
| `user_arn` | ARN of the user/role making the change | `arn:aws:iam::123456789012:user/admin` |
| `group_id` | The ID of the security group | `sg-0123456789abcdef0` |
| `change_details` | Description of the rule change | `Ingress: ALLOW TCP 22 from 0.0.0.0/0` |
| `source_ip` | IP address of the requestor | `198.51.100.5` |

## 2. Application-Level Events

### 2.1. Failed API Authentication

- **Description**: A high volume of failed login attempts can signal credential stuffing, password spraying, or brute-force attacks.
- **Logging Context**:
| Field | Description | Example |
| :--- | :--- | :--- |
| `timestamp` | ISO 8601 timestamp | `2023-10-27T10:25:00Z` |
| `source_ip` | IP address of the client | `203.0.113.50` |
| `user_id` | The user ID or email attempted | `user@example.com` |
| `endpoint` | The API endpoint targeted | `/api/v1/auth/login` |
| `user_agent` | The client's User-Agent string | `Mozilla/5.0...` |
| `outcome` | `failure` | `failure` |

### 2.2. User Permission Escalation

- **Description**: A user gaining permissions they should not have, either maliciously or accidentally.
- **Logging Context**:
| Field | Description | Example |
| :--- | :--- | :--- |
| `timestamp` | ISO 8601 timestamp | `2023-10-27T10:30:00Z` |
| `actor_user_id` | User performing the action | `admin@example.com` |
| `target_user_id` | User whose permissions were changed | `user@example.com` |
| `permission_change` | Description of the change | `role: editor -> admin` |
| `source_ip` | IP address of the actor | `198.51.100.12` |

### 2.3. Sensitive Data Access

- **Description**: Monitoring access to critical data or admin-level endpoints to detect unauthorized activity.
- **Logging Context**:
| Field | Description | Example |
| :--- | :--- | :--- |
| `timestamp` | ISO 8601 timestamp | `2023-10-27T10:35:00Z` |
| `user_id` | The user accessing the data | `user@example.com` |
| `resource_id` | The identifier of the resource | `customer/12345` |
| `endpoint` | The API endpoint accessed | `/api/v1/admin/data` |
| `source_ip` | IP address of the client | `203.0.113.55` |

### 2.4. SQL Injection Attempts

- **Description**: Detecting patterns indicative of SQL injection in API requests.
- **Logging Context**:
| Field | Description | Example |
| :--- | :--- | :--- |
| `timestamp` | ISO 8601 timestamp | `2023-10-27T10:40:00Z` |
| `source_ip` | IP address of the client | `198.51.100.80` |
| `endpoint` | The targeted API endpoint | `/api/v1/products` |
| `payload` | The malicious payload | `{"id": "1' OR '1'='1"}` |
| `user_agent` | The client's User-Agent string | `sqlmap/1.5.9` |

### 2.5. Account Lockouts

- **Description**: Frequent account lockouts for a specific user might indicate a targeted attack or an attempt to deny service.
- **Logging Context**:
| Field | Description | Example |
| :--- | :--- | :--- |
| `timestamp` | ISO 8601 timestamp | `2023-10-27T10:45:00Z` |
| `user_id` | The user account that was locked | `user@example.com` |
| `reason` | Reason for lockout | `Too many failed login attempts` |
| `source_ip` | Last known IP for a failed attempt | `203.0.113.90` |
