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

	// Get outputs
	publicIP := terraform.Output(t, terraformOptions, "edge_public_ip")
	keyPath := terraform.Output(t, terraformOptions, "edge_private_key_path")
	// New: Get registry_url output
	registryURL := terraform.Output(t, terraformOptions, "registry_url")
	t.Logf("[INFO] Registry URL: %s", registryURL)

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

	t.Log("\033[1;34m[INFO]\033[0m Polling for cloud-init completion signal...")
	maxWait := 900 // seconds (15 min max)
	pollInterval := 10 * time.Second
	found := false
	for i := 0; i < maxWait/int(pollInterval.Seconds()); i++ {
		out, err := ssh.CheckSshCommandE(t, host, "test -f /var/lib/cloud/instance/cloud-init-finished && echo done || echo notyet")
		if err == nil && strings.TrimSpace(out) == "done" {
			found = true
			t.Log("[SUCCESS] Cloud-init finished signal detected.")
			break
		}
		t.Logf("Still waiting for cloud-init... (%d/%d)", i+1, maxWait/int(pollInterval.Seconds()))
		time.Sleep(pollInterval)
	}
	if !found {
		t.Fatalf("Cloud-init did not finish within %d seconds", maxWait)
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

	t.Log("\033[1;34m[INFO]\033[0m Checking Docker installation...")
	dockerVersionCmd := "docker --version"
	dockerVersionOut, err := ssh.CheckSshCommandE(t, host, dockerVersionCmd)
	require.NoError(t, err, "Docker should be installed and available in PATH")
	t.Logf("Docker version: %s", dockerVersionOut)

	// --- Docker Registry & Caddy Tests ---
	t.Log("\033[1;34m[INFO]\033[0m Checking Docker registry container...")
	regPsCmd := "sudo docker ps --format '{{.Image}}'"
	regPsOut, err := ssh.CheckSshCommandE(t, host, regPsCmd)
	require.NoError(t, err, "Failed to list running Docker containers")
	assert.Contains(t, regPsOut, "registry:3", "Docker registry container should be running")

	t.Log("\033[1;34m[INFO]\033[0m Checking Caddyfile for registry domain...")
	caddyfileCmd := "sudo cat /etc/caddy/Caddyfile"
	caddyfileOut, err := ssh.CheckSshCommandE(t, host, caddyfileCmd)
	assert.NoError(t, err)
	assert.Contains(t, caddyfileOut, strings.TrimPrefix(registryURL, "https://"), "Caddyfile should contain the registry domain")

	t.Log("\033[1;34m[INFO]\033[0m Checking htpasswd file for registry user...")
	htpasswdCmd := "sudo cat /opt/registry/auth/htpasswd"
	htpasswdOut, err := ssh.CheckSshCommandE(t, host, htpasswdCmd)
	assert.NoError(t, err)
	assert.Contains(t, htpasswdOut, "registry", "htpasswd file should contain the registry user")

	// Optionally: Test HTTPS endpoint and basic auth (skipped here, as it requires network setup)

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

		t.Log("\033[1;34m[INFO]\033[0m Checking fail2ban service...")
	// fail2ban: Check service is active
	fail2banCmd := "sudo systemctl is-active fail2ban"
	fail2banOut, err := ssh.CheckSshCommandE(t, host, fail2banCmd)
	assert.NoError(t, err)
	assert.Equal(t, "active", strings.TrimSpace(fail2banOut), "fail2ban service should be active")
	if strings.TrimSpace(fail2banOut) == "active" {
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m fail2ban service is active")
	} else {
		t.Log("\033[1;31m❌ [FAIL]\033[0m fail2ban service is not active")
	}

	t.Log("\033[1;34m[INFO]\033[0m Checking fail2ban sshd jail...")
	// fail2ban: Check sshd jail is present
	jailCmd := "sudo fail2ban-client status sshd"
	jailOut, err := ssh.CheckSshCommandE(t, host, jailCmd)
	assert.NoError(t, err)
	assert.Contains(t, jailOut, "Status for the jail: sshd", "fail2ban sshd jail should be present")
	if strings.Contains(jailOut, "Status for the jail: sshd") {
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m fail2ban sshd jail is present")
	} else {
		t.Log("\033[1;31m❌ [FAIL]\033[0m fail2ban sshd jail is missing")
	}
}
