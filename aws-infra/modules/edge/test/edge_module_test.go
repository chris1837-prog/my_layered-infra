package test

import (
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestEdgeModuleIntegration(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/basic_usage",
		NoColor:      true,
	}

	// Clean up resources with 'terraform destroy' at the end of the test.
	defer terraform.Destroy(t, terraformOptions)

	// Init and apply the Terraform code
	terraform.InitAndApply(t, terraformOptions)

	t.Log("\033[1;34m[INFO]\033[0m Waiting 120s for cloud-init to finish...")
	time.Sleep(120 * time.Second)

	// Get outputs
	publicIP := terraform.Output(t, terraformOptions, "edge_public_ip")
	keyPath := terraform.Output(t, terraformOptions, "edge_private_key_path")

	// Read the private key
	privateKey, err := os.ReadFile(keyPath)
	if err != nil {
		t.Fatalf("Failed to read private key: %v", err)
	}

	host := ssh.Host{
		Hostname:    publicIP,
		SshUserName: "ubuntu",
		SshKeyPair:  &ssh.KeyPair{PrivateKey: string(privateKey)},
	}

	t.Log("\033[1;34m[INFO]\033[0m Checking SSH availability...")
	// Wait for SSH to be available (retry for up to 2 minutes)
	maxRetries := 24
	sleepBetweenRetries := 5 * time.Second
	for i := 0; i < maxRetries; i++ {
		err := ssh.CheckSshConnectionE(t, host)
		if err == nil {
			t.Log("\033[1;32m[SUCCESS]\033[0m SSH is available")
			break
		}
		if i == maxRetries-1 {
			t.Fatalf("SSH not available after retries: %v", err)
		}
		time.Sleep(sleepBetweenRetries)
	}

	t.Log("\033[1;34m[INFO]\033[0m Checking NAT MASQUERADE rule...")
	// NAT: Check for MASQUERADE rule
	natCmd := "sudo iptables -t nat -S"
	natOut, err := ssh.CheckSshCommandE(t, host, natCmd)
	assert.NoError(t, err)
	assert.Contains(t, natOut, "MASQUERADE", "NAT MASQUERADE rule should exist")
	if strings.Contains(natOut, "MASQUERADE") {
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m NAT MASQUERADE rule exists")
	} else {
		t.Log("\033[1;31m❌ [FAIL]\033[0m NAT MASQUERADE rule missing")
	}

	t.Log("\033[1;34m[INFO]\033[0m Checking WireGuard service...")
	// WireGuard: Check service is active
	wgCmd := "sudo systemctl is-active wg-quick@wg0"
	wgOut, err := ssh.CheckSshCommandE(t, host, wgCmd)
	assert.NoError(t, err)
	assert.Equal(t, "active", strings.TrimSpace(wgOut), "WireGuard service should be active")
	if strings.TrimSpace(wgOut) == "active" {
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m WireGuard service is active")
	} else {
		t.Log("\033[1;31m❌ [FAIL]\033[0m WireGuard service is not active")
	}

	t.Log("\033[1;34m[INFO]\033[0m Checking Caddy service...")
	// Caddy: Check service is active
	caddyCmd := "sudo systemctl is-active caddy"
	caddyOut, err := ssh.CheckSshCommandE(t, host, caddyCmd)
	assert.NoError(t, err)
	assert.Equal(t, "active", strings.TrimSpace(caddyOut), "Caddy service should be active")
	if strings.TrimSpace(caddyOut) == "active" {
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m Caddy service is active")
	} else {
		t.Log("\033[1;31m❌ [FAIL]\033[0m Caddy service is not active")
	}
}
