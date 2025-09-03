package test

import (
	"fmt"
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
)

func TestPrivateEgressFull(t *testing.T) {
	t.Parallel()

	terraformDir := "../examples/private_egress_via_edge"

	tfOpts := &terraform.Options{
		TerraformDir: terraformDir,
	}

	terraform.InitAndApply(t, tfOpts)
	defer terraform.Destroy(t, tfOpts)

	edgeIP := terraform.Output(t, tfOpts, "edge_public_ip")
	edgeInstanceID := terraform.Output(t, tfOpts, "edge_instance_id")
	edgeNI := terraform.Output(t, tfOpts, "edge_primary_network_interface_id")
	privateIP := terraform.Output(t, tfOpts, "private_test_private_ip")
	privateID := terraform.Output(t, tfOpts, "private_test_instance_id")
	privateRT := terraform.Output(t, tfOpts, "private_route_table_id")
	vpcCIDR := terraform.Output(t, tfOpts, "vpc_cidr")
	keyFile := terraform.Output(t, tfOpts, "ssh_private_key_file")

	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "eu-central-1"
	}

	sess := session.Must(session.NewSession(&aws.Config{Region: aws.String(region)}))
	ec2Client := ec2.New(sess)

	// Check edge instance SourceDestCheck
	desc, err := ec2Client.DescribeInstances(&ec2.DescribeInstancesInput{InstanceIds: []*string{aws.String(edgeInstanceID)}})
	require.NoError(t, err)
	edgeInstance := desc.Reservations[0].Instances[0]
	require.False(t, aws.BoolValue(edgeInstance.SourceDestCheck))

	// Check private route table routes 0.0.0.0/0 via edge
	rtOut, err := ec2Client.DescribeRouteTables(&ec2.DescribeRouteTablesInput{RouteTableIds: []*string{aws.String(privateRT)}})
	require.NoError(t, err)

	found := false
	for _, r := range rtOut.RouteTables[0].Routes {
		if r.DestinationCidrBlock != nil && aws.StringValue(r.DestinationCidrBlock) == "0.0.0.0/0" {
			if (r.NetworkInterfaceId != nil && aws.StringValue(r.NetworkInterfaceId) == edgeNI) ||
				(r.InstanceId != nil && aws.StringValue(r.InstanceId) == edgeInstanceID) {
				found = true
			}
		}
	}
	require.True(t, found, "private route table must route 0.0.0.0/0 to edge instance")

	// Check iptables MASQUERADE rule
	iptCmd := fmt.Sprintf("sudo iptables -t nat -S | grep -i MASQUERADE || true")
	iptOut, err := RetrySSHCommand(t, edgeIP, "ubuntu", keyFile, iptCmd)
	require.NoError(t, err)
	require.Contains(t, iptOut, "MASQUERADE")
	require.Contains(t, iptOut, vpcCIDR)

	// From private instance: curl test
	nestedScript := fmt.Sprintf(`
cat > /tmp/testkey <<'EOF'
%s
EOF
chmod 600 /tmp/testkey
ssh -o StrictHostKeyChecking=no -i /tmp/testkey ubuntu@%s "sudo apt-get update -y && sudo apt-get install -y curl && curl -sI https://api.github.com | head -n 1"
`, keyFile, privateIP)

	curlOut, err := RetrySSHCommand(t, edgeIP, "ubuntu", keyFile, nestedScript)
	require.NoError(t, err)
	require.Contains(t, curlOut, "200")

	t.Logf("Success: private instance (%s) reached internet via edge (%s)", privateID, edgeInstanceID)
}

