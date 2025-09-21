import datetime
from unittest.mock import patch
from functions.e1AutoStop import stop_instances


def fake_instance(instance_id, launch_time):
    return {
        "InstanceId": instance_id,
        "LaunchTime": launch_time,
        "State": {"Name": "running"},
        "Tags": [{"Key": "Environment", "Value": "QA"}]
    }


@patch("e1AutoStop.stop_instances.boto3.client")
def test_lambda_handler_stops_old_instances(mock_boto_client):
    now = datetime.datetime.now(datetime.timezone.utc)
    old_instance = fake_instance("i-old", now - datetime.timedelta(minutes=10))
    new_instance = fake_instance("i-new", now - datetime.timedelta(minutes=2))

    ec2_mock = mock_boto_client.return_value
    ec2_mock.describe_instances.return_value = {
        "Reservations": [{"Instances": [old_instance, new_instance]}]
    }

    env = {
        "ENV_TAG_KEY": "Environment",
        "ENV_TAG_VALUE": "QA",
        "THRESHOLD_MINUTES": "5",
        "DRY_RUN": "true"
    }

    with patch.dict("os.environ", env):
        stop_instances.lambda_handler({}, {})

    ec2_mock.stop_instances.assert_called_once_with(
        InstanceIds=["i-old"],
        DryRun=True
    )


@patch("e1AutoStop.stop_instances.boto3.client")
def test_lambda_handler_no_stop_if_none_exceed(mock_boto_client):
    now = datetime.datetime.now(datetime.timezone.utc)
    instances = [
        fake_instance("i1", now - datetime.timedelta(minutes=2)),
        fake_instance("i2", now - datetime.timedelta(minutes=1))
    ]

    ec2_mock = mock_boto_client.return_value
    ec2_mock.describe_instances.return_value = {
        "Reservations": [{"Instances": instances}]
    }

    env = {
        "ENV_TAG_KEY": "Environment",
        "ENV_TAG_VALUE": "QA",
        "THRESHOLD_MINUTES": "5",
        "DRY_RUN": "true"
    }

    with patch.dict("os.environ", env):
        stop_instances.lambda_handler({}, {})

    ec2_mock.stop_instances.assert_not_called()
