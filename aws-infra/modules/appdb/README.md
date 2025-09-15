
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

