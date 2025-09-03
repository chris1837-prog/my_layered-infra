package test

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

// Simple test: private instance can reach the internet via Edge NAT
func TestPrivateEgressSimple(t *testing.T) {
	t.Parallel()

	terraformDir := "../examples/private_egress_via_edge"

	tfOpts := &terraform.Options{
		TerraformDir: terraformDir,
		// vars like admin_ssh_public_key already passed in main.tf via Terraform local_file
	}

	terraform.InitAndApply(t, tfOpts)
	defer terraform.Destroy(t, tfOpts)

	edgeIP := terraform.Output(t, tfOpts, "edge_public_ip")
	privateIP := terraform.Output(t, tfOpts, "private_test_private_ip")
	keyFile := terraform.Output(t, tfOpts, "ssh_private_key_file")

	// Simple curl test from private instance via edge
	nestedScript := fmt.Sprintf(`
ssh -o StrictHostKeyChecking=no -i %s ubuntu@%s "sudo apt-get update -y && sudo apt-get install -y curl && curl -sI https://api.github.com | head -n 1"
`, keyFile, privateIP)

	out, err := RetrySSHCommand(t, edgeIP, "ubuntu", keyFile, nestedScript)
	require.NoError(t, err)
	require.Contains(t, out, "200", "expected HTTP 200 from https://api.github.com")

	t.Logf("Success: private instance (%s) can reach internet via edge (%s)", privateIP, edgeIP)
}

