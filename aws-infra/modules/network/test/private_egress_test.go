package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

// TestPrivateEgressHTTPS validates that the private instance
// can reach the public internet via the Edge NAT instance.
func TestPrivateEgressHTTPS(t *testing.T) {
	t.Parallel()

	terraformDir := "../examples/private_egress_via_edge"
	tfOpts := &terraform.Options{
		TerraformDir: terraformDir,
	}

	t.Log("🚀 Starting Terraform apply for private egress test...")
	defer func() {
		t.Log("🧹 Destroying Terraform resources...")
		terraform.Destroy(t, tfOpts)
		t.Log("✅ Terraform destroy complete.")
	}()

	terraform.InitAndApply(t, tfOpts)
	t.Log("✅ Terraform apply complete, infrastructure provisioned.")

	// Collect outputs
	t.Log("📦 Collecting Terraform outputs...")
	edgeIP := terraform.Output(t, tfOpts, "edge_public_ip")
	privateIP := terraform.Output(t, tfOpts, "private_test_private_ip")
	keyFile := ResolveKeyPath(t, terraform.Output(t, tfOpts, "ssh_private_key_file"))
	t.Logf("🌐 Edge public IP: %s | 🔒 Private IP: %s | 🔑 Key: %s", edgeIP, privateIP, keyFile)

	// Command to run on private instance
	cmd := "curl -sI https://api.github.com | head -n 1"
	t.Logf("🖥️  Test command to run on private instance: %q", cmd)

	// Use helpers.go with retry + edge tunnel
	t.Log("🔁 Executing curl from private instance via Edge tunnel...")
	out, err := RetrySSHViaEdge(t, edgeIP, privateIP, "ubuntu", keyFile, cmd)

	require.NoError(t, err, "SSH command via edge host failed")
	require.Contains(t, out, "200", "expected HTTP 200 from https://api.github.com")

	t.Logf("🎉 SUCCESS: Private instance %s reached internet via Edge %s (got response: %q)", privateIP, edgeIP, out)
}

