import boto3
from datetime import datetime, timezone, timedelta

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    print("🔍 Starting orphaned resource cleanup...")

    now = datetime.now(timezone.utc)
    seven_days_ago = now - timedelta(days=7)
    ninety_days_ago = now - timedelta(days=90)

    # --- Cleanup Unattached EBS Volumes ---
    volumes = ec2.describe_volumes(
        Filters=[{"Name": "status", "Values": ["available"]}]
    )["Volumes"]

    for volume in volumes:
        vol_id = volume["VolumeId"]
        create_time = volume["CreateTime"]

        if create_time < seven_days_ago:
            print(f"📦 Creating snapshot for volume {vol_id}")
            snapshot = ec2.create_snapshot(VolumeId=vol_id, Description="Auto-snapshot before deletion")
            ec2.create_tags(Resources=[snapshot["SnapshotId"]], Tags=[{"Key": "CreatedBy", "Value": "orphaned-cleanup"}])

            print(f"❌ Deleting volume {vol_id}")
            ec2.delete_volume(VolumeId=vol_id)

    # --- Cleanup old Snapshots ---
    snapshots = ec2.describe_snapshots(OwnerIds=["self"])["Snapshots"]

    for snap in snapshots:
        snap_id = snap["SnapshotId"]
        start_time = snap["StartTime"]

        tags = {tag["Key"]: tag["Value"] for tag in snap.get("Tags", [])}
        if start_time < ninety_days_ago and tags.get("Retention") != "Forever":
            print(f"🧹 Deleting old snapshot {snap_id}")
            ec2.delete_snapshot(SnapshotId=snap_id)

    print("✅ Cleanup completed.")