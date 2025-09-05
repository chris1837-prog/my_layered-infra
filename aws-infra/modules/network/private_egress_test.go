package test

import (
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestPrivateEgressHTTPS200(t *testing.T) {
	t.Parallel()

	terraformDir := "../examples/private_egress_via_edge"
	terraformOptions := &terraform.Options{
		TerraformDir: terraformDir,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Wait 2 minutes for Edge instance to finish booting and cloud-init
	t.Log("Waiting 2 minutes for Edge instance to finish booting...")
	time.Sleep(2 * time.Minute)

	edgePublicIP := terraform.Output(t, terraformOptions, "edge_public_ip")
	privateIP := terraform.Output(t, terraformOptions, "private_test_private_ip")
	privateKeyPath := terraform.Output(t, terraformOptions, "ssh_private_key_file")

	// Check key file exists
	keyBytes, err := os.ReadFile(privateKeyPath)
	assert.NoError(t, err, "Failed to read private key file")

	keyPair := ssh.KeyPair{
		PrivateKey: string(keyBytes),
	}

	edgeHost := ssh.Host{
		Hostname:    edgePublicIP,
		SshUserName: "ubuntu",
		SshKeyPair:  &keyPair,
	}

	// Wait for SSH to be available
	ssh.CheckSshConnection(t, edgeHost)

	// Copy private key to Edge instance
	remoteKeyPath := "/tmp/network_test_key.pem"
	ssh.ScpFileTo(t, edgeHost, 0600, remoteKeyPath, string(keyBytes))

	// SSH from Edge to Private instance and run curl
	curlCmd := "ssh -i /tmp/network_test_key.pem -o StrictHostKeyChecking=no ubuntu@" + privateIP + " 'curl -sI https://api.github.com | head -n 1'"
	output, err := ssh.CheckSshCommandE(t, edgeHost, curlCmd)
	assert.NoError(t, err)
	assert.Contains(t, output, "200")
	t.Log("SUCCESS: SSH from Edge to Private and outbound HTTPS verified!")
}
