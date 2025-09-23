import boto3
import os

ec2 = boto3.client('ec2')
tag_key = os.environ.get('TAG_KEY', 'Environment')
tag_value = os.environ.get('TAG_VALUE', 'QA')


def lambda_handler(event, _context):
    action = event.get("action")
    print(f"Triggered with action={action}, tag_key={tag_key}, tag_value={tag_value}")

    if action not in ["start", "stop"]:
        return {
            "statusCode": 400,
            "body": f"Invalid action: {action}. Must be 'start' or 'stop'."
        }

    filters = [{'Name': f'tag:{tag_key}', 'Values': [tag_value]}]
    response = ec2.describe_instances(Filters=filters)

    instance_ids = [
        i['InstanceId']
        for reservation in response.get('Reservations', [])
        for i in reservation.get('Instances', [])
        if i.get('State', {}).get('Name') in ['running', 'stopped']
    ]

    print(f"Found instances: {instance_ids}")

    if not instance_ids:
        return {"statusCode": 200, "body": f"No instances to {action}"}

    if action == 'stop':
        ec2.stop_instances(InstanceIds=instance_ids)
    elif action == 'start':
        ec2.start_instances(InstanceIds=instance_ids)

    return {
        "statusCode": 200,
        "body": f"{action.capitalize()}ed: {instance_ids}"
    }
