
# appdb Terraform Module

This module provisions an EC2 instance running your App + Postgres database stack using Docker Compose. 
It uses **cloud-init** to bootstrap the instance, pull images from your internal Docker registry, and start the stack automatically.  

The module is designed for private subnets in a VPC and integrates with AWS SSM Parameter Store for configuration values.

---

## Directory Structure

```

appdb/
├── templates
│       └── cloud-init.yaml.tftpl        # cloud-init template for EC2 bootstrap
├── examples/                    # Example usage (placeholder)
│   └── basic_usage/
│       ├── main.tf
│       ├── outputs.tf
│       └── versions.tf
├── main.tf                      # EC2 instance and cloud-init data source
├── locals.tf                     # Local values for AMI lookup and tags
├── outputs.tf                    # Module outputs
├── variables.tf                  # Module input variables
├── versions.tf                   # Terraform version and provider constraints
└── README.md
````

---

## Usage

**Note:** Replace the placeholders with your actual subnet IDs, security groups, and SSM parameter paths.

```hcl
module "appdb" {
  source = "../path-to-module/appdb"

  project_name       = "myproject"
  environment        = "dev"
  common_tags        = { Owner = "team" }

  ubuntu_version     = "22.04"
  instance_type      = "t3.medium"
  private_subnet_id  = "subnet-xxxxxxxx"
  sg_app_id          = "sg-xxxxxxxx"
  appdb_instance_profile_name = "appdb-instance-profile"

  ebs_volume_size    = 20
  ebs_volume_type    = "gp3"
  delete_on_termination = true
  enable_monitoring     = false
  enable_ebs_optimized  = true

  app_image_name              = "myapp"
  ssm_internal_registry_url_path = "/myproject/dev/registry_url"
  ssm_app_image_tag_path      = "/myproject/dev/app_image_tag"
  ssm_postgres_user_path      = "/myproject/dev/postgres_user"
  ssm_postgres_password_path  = "/myproject/dev/postgres_password"
  ssm_postgres_db_path        = "/myproject/dev/postgres_db"
  ssm_registry_user_path      = "/myproject/dev/registry_user"      # optional
  ssm_registry_password_path  = "/myproject/dev/registry_password"  # optional
}
````

### Examples

> Placeholder for `examples/basic_usage/main.tf`. You can provide a ready-to-run example later.

---

## Variables

| Name                               | Type        | Default     | Description                               |
|------------------------------------|-------------|-------------|-------------------------------------------|
| project\_name                      | string      | ""          | Project name to tag resources             |
| environment                        | string      | -           | Environment name (dev/staging/prod)       |
| common\_tags                       | map(string) | `{}`        | Map of tags to apply to all resources     |
| ubuntu\_version                    | string      | "22.04"     | Ubuntu version for EC2 AMI                |
| instance\_type                     | string      | "t3.medium" | EC2 instance type                         |
| private\_subnet\_id                | string      | -           | Private subnet ID                         |
| sg\_app\_id                        | string      | -           | Security group ID for appdb               |
| appdb\_instance\_profile\_name     | string      | null        | Optional IAM instance profile             |
| ebs\_volume\_size                  | number      | 20          | Root EBS volume size (GB)                 |
| ebs\_volume\_type                  | string      | "gp3"       | Root EBS volume type                      |
| delete\_on\_termination            | bool        | true        | Delete root volume on termination         |
| enable\_monitoring                 | bool        | false       | Enable 1-min detailed CloudWatch metrics  |
| enable\_ebs\_optimized             | bool        | true        | Enable EBS optimization                   |
| app\_image\_name                   | string      | -           | Application Docker image name             |
| ssm\_internal\_registry\_url\_path | string      | -           | SSM path for internal registry URL        |
| ssm\_app\_image\_tag\_path         | string      | -           | SSM path for app image tag                |
| ssm\_postgres\_user\_path          | string      | -           | SSM path for Postgres username            |
| ssm\_postgres\_password\_path      | string      | -           | SSM path for Postgres password            |
| ssm\_postgres\_db\_path            | string      | -           | SSM path for Postgres database name       |
| ssm\_registry\_user\_path          | string      | -           | SSM path for registry username (optional) |
| ssm\_registry\_password\_path      | string      | -           | SSM path for registry password (optional) |

---

## Outputs

| Name                | Description                                    |
|---------------------|------------------------------------------------|
| appdb\_instance\_id | ID of the appdb EC2 instance                   |
| appdb\_private\_ip  | Private IP of the appdb EC2 instance           |
| appdb\_subnet\_id   | Subnet ID where the appdb instance is deployed |

---

## Notes

* Cloud-init handles pulling Docker images, creating override compose files, and starting the stack.
* `docker-compose.override.yml` is dynamically generated based on SSM parameters.
* The module is designed for private VPC environments; registry authentication is optional if using an internal registry accessible from the subnet.
* For persistence of Postgres data, attach additional EBS volumes instead of relying on `delete_on_termination = true`.

---

### Future Production Extension: Dedicated EBS Volume

Once you move from development to production, you can attach a dedicated EBS volume to persist database data:

1. **Terraform Variables**
   Define new variables in your module for volume configuration:

   ```hcl
   variable "db_volume_size" {
     type    = number
     default = 50
     description = "Size of the dedicated EBS volume for database (GB)"
   }
    
   variable "db_volume_type" {
     description = "EBS type for Postgres data volume"
     type        = string
     default     = "gp3"
   }
   variable "db_device" {
     type    = string
     default = "/dev/sdf"
     description = "Device name for the dedicated EBS volume"
   }

   variable "db_mount_path" {
     type    = string
     default = "/var/lib/postgresql/data"
     description = "Mount path for the dedicated EBS volume"
   }
   ```

2. **Attach Volume to EC2**
   Add a `ebs_block_device` block to your `aws_instance` resource, using the variables above.
   ```hcl
    # Define a dedicated EBS volume for database
    resource "aws_ebs_volume" "db_data" {
        availability_zone = aws_instance.app.availability_zone
        size              = var.db_volume_size       # e.g., 50 GB
        type              = var.db_volume_type       # e.g., gp3
        encrypted         = true
        tags = merge(
            { Name = "${var.project_name}-${var.environment}-db-data" },
            var.common_tags
        )
    }

    # Attach the volume to the EC2 instance
    resource "aws_volume_attachment" "db_data_attach" {
        device_name = "/dev/xvdh"                     # Pick an unused device name
        instance_id = aws_instance.app.id
        volume_id   = aws_ebs_volume.db_data.id
    }

    # Inside cloud-init, mount it to /var/lib/postgresql/data
    # and ensure Docker volume for Postgres points to it
    ```
3. **Cloud-init Integration**
   In your cloud-init template, add a block before starting Docker to:

   * Format the volume if it’s empty
   * Mount it to `${db_mount_path}`
   * Update `/etc/fstab` for persistence

   ```yaml
   #cloud-config
   runcmd:
     - |
       # Format volume if empty
       if ! file -s ${db_device} | grep -q ext4; then
         mkfs -t ext4 ${db_device}
       fi
       mkdir -p ${db_mount_path}
       mount ${db_device} ${db_mount_path}
       echo "${db_device} ${db_mount_path} ext4 defaults,nofail 0 2" >> /etc/fstab
   ```

4. **Docker / Application**
   After mounting the volume, your containers (Postgres, PgBouncer, or app) can use `${db_mount_path}` to store persistent data.

> This approach keeps development lightweight (no dedicated EBS) while allowing a smooth upgrade to persistent storage for production.

---

# Example: Basic usage of Appdb module

This example provisions a **standalone test environment** to validate the `appdb` module.  
It deploys a simple VPC with one public subnet and one private subnet, along with:

- **Edge instance (public)**: Acts as a NAT gateway and SSH jump host.  
- **AppDB instance (private)**: Runs a minimal nginx container to simulate the database service.  

The purpose of this setup is to test connectivity, routing, and basic module functionality **without depending on other modules**.  
---

## Structure
    ```
    examples/basic_usage/
    ├── main.tf # Standalone test setup (VPC, Edge NAT, AppDB instance)
    ├── outputs.tf # Useful output values
    ├── versions.tf # Terraform version and providers
    └── templates/
        ├── cloud-init.yaml.tftpl # Cloud-init config for AppDB (runs Docker + nginx)
        └── edge_init.sh.tftpl user_data config for Edge instance

    ```

---

## Architecture

- **VPC**: `10.0.0.0/16`
- **Subnets**:
  - Public: `10.0.1.0/24` (for Edge)
  - Private: `10.0.2.0/24` (for AppDB)
- **Edge Instance**:
  - Public IP for inbound SSH
  - Configured with IP forwarding + iptables to NAT private traffic
- **AppDB Instance**:
  - Private only (no public IP)
  - Cloud-init installs Docker, pulls nginx, and serves a test page:
    ```
    Hello from nginx!
    ```

---

## How to Provision

```bash
cd examples/basic_usage
terraform init
terraform apply -auto-approve
```

Terraform will generate an SSH keypair (`appdb_test_key.pem`) in this folder and create the required infrastructure.

---

## Testing

1. **SSH into the Edge instance** (publicly accessible):

   ```bash
   terraform output -raw edge_ssh_command
   ```

2. **Copy the AppDB private key** to the Edge instance:

   ```bash
   terraform output -raw scp_key_to_edge
   ```

3. **SSH into the AppDB instance from Edge**:

   ```bash
   terraform output -raw appdb_ssh_command
   ```

4. **Test nginx inside AppDB**:

   ```bash
   curl -I http://localhost
   ```

   Expected output (headers):

   ```
   HTTP/1.1 200 OK
   Server: nginx/1.25.x
   Content-Type: text/html
   ```

   The default index page contains:

   ```
   Hello from nginx!
   ```

5. **Alternatively, test directly from Edge** (without SSHing into AppDB):

   ```bash
   curl -I http://$(terraform output -raw appdb_private_ip)
   ```

   Expected: same HTTP 200 OK response from nginx.

---

## Cleanup

When finished, destroy the environment:

```bash
terraform destroy -auto-approve
rm -f appdb_test_key.pem
```





