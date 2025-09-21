import os
import boto3
from datetime import datetime, timezone, timedelta

# Initialize EC2 client
ec2 = boto3.client("ec2")

# Get environment variables
ENV_TAG_KEY = os.environ.get("ENV_TAG_KEY", "Environment")
ENV_TAG_VALUE = os.environ.get("ENV_TAG_VALUE", "QA")
THRESHOLD_MINUTES = int(os.environ.get("THRESHOLD_MINUTES", "120"))
DRY_RUN = os.environ.get("DRY_RUN", "true").lower() == "true"

def lambda_handler(event, context):
    now = datetime.now(timezone.utc)
    threshold = timedelta(minutes=THRESHOLD_MINUTES)

    print(f"Looking for EC2 instances tagged {ENV_TAG_KEY}={ENV_TAG_VALUE} running longer than {THRESHOLD_MINUTES} minutes (DRY_RUN={DRY_RUN})")

    # Fetch all running instances with the QA environment tag
    filters = [
        {"Name": "tag:" + ENV_TAG_KEY, "Values": [ENV_TAG_VALUE]},
        {"Name": "instance-state-name", "Values": ["running"]}
    ]

    response = ec2.describe_instances(Filters=filters)

    stop_candidates = []

    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            instance_id = instance["InstanceId"]
            launch_time = instance["LaunchTime"]
            run_time = now - launch_time

            print(f"Instance {instance_id} launched at {launch_time}, running for {run_time}")

            if run_time > threshold:
                print(f"→ Marked for stopping: {instance_id}")
                stop_candidates.append(instance_id)
            else:
                print(f"→ OK: {instance_id} below threshold.")

    if not stop_candidates:
        print("✅ No instances need stopping.")
        return

    try:
        ec2.stop_instances(InstanceIds=stop_candidates, DryRun=DRY_RUN)
        if DRY_RUN:
            print(f"🧪 DRY RUN: Would have stopped: {stop_candidates}")
        else:
            print(f"🛑 Stopped instances: {stop_candidates}")
    except Exception as e:
        print(f"⚠️ Failed to stop instances: {e}")