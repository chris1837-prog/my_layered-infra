package test

import (
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
		// variables already handled in Terraform main.tf
	}

	// Provision infrastructure
	terraform.InitAndApply(t, tfOpts)
	defer terraform.Destroy(t, tfOpts)

	// Get outputs
	edgeIP := terraform.Output(t, tfOpts, "edge_public_ip")
	privateIP := terraform.Output(t, tfOpts, "private_test_private_ip")
	keyFile := ResolveKeyPath(t, terraform.Output(t, tfOpts, "ssh_private_key_file"))

	// Command to run on private instance
	cmd := "curl -sI https://api.github.com | head -n 1"

	// Execute via edge instance
	out, err := RetrySSHViaEdge(t, edgeIP, privateIP, "ubuntu", keyFile, cmd)
	require.NoError(t, err)
	require.Contains(t, out, "200", "expected HTTP 200 from https://api.github.com")

	t.Logf("Success: private instance (%s) can reach internet via edge (%s)", privateIP, edgeIP)
}


