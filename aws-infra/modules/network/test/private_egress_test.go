package test

import (
	"bytes"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/stretchr/testify/require"

	gossh "golang.org/x/crypto/ssh"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
)

// ---------- Helpers ----------

// generateRSAKeyPair generates a fresh 2048-bit RSA key pair and returns the PEM private key
// and the OpenSSH public key (authorized_keys format).
func generateRSAKeyPair(t *testing.T) (privatePEM string, publicKey string) {
	t.Helper()

	key, err := rsa.GenerateKey(rand.Reader, 2048)
	require.NoError(t, err)

	privDER := x509.MarshalPKCS1PrivateKey(key)
	privBlock := &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: privDER,
	}
	privBuf := &bytes.Buffer{}
	require.NoError(t, pem.Encode(privBuf, privBlock))

	// Build OpenSSH public key
	pub, err := gossh.NewPublicKey(&key.PublicKey)
	require.NoError(t, err)
	pubBytes := gossh.MarshalAuthorizedKey(pub)

	return privBuf.String(), strings.TrimSpace(string(pubBytes))
}

// runSSHCommand runs `cmd` on host (hostname or ip) using username and privateKeyPEM.
// Returns combined stdout+stderr.
func runSSHCommand(t *testing.T, hostname, username, privateKeyPEM, cmd string) (string, error) {
	t.Helper()

	signer, err := gossh.ParsePrivateKey([]byte(privateKeyPEM))
	if err != nil {
		return "", fmt.Errorf("parse private key: %w", err)
	}

	config := &gossh.ClientConfig{
		User:            username,
		Auth:            []gossh.AuthMethod{gossh.PublicKeys(signer)},
		HostKeyCallback: gossh.InsecureIgnoreHostKey(),
		Timeout:         30 * time.Second,
	}

	client, err := gossh.Dial("tcp", fmt.Sprintf("%s:22", hostname), config)
	if err != nil {
		return "", fmt.Errorf("ssh dial %s: %w", hostname, err)
	}
	defer client.Close()

	session, err := client.NewSession()
	if err != nil {
		return "", fmt.Errorf("new session: %w", err)
	}
	defer session.Close()

	var combined bytes.Buffer
	session.Stdout = &combined
	session.Stderr = &combined

	if err := session.Run(cmd); err != nil {
		// We return output plus the error.
		return combined.String(), fmt.Errorf("run cmd: %w (output: %s)", err, combined.String())
	}
	return combined.String(), nil
}

// getMyPublicIP queries a simple external endpoint to obtain the test runner's public IP
func getMyPublicIP(t *testing.T) string {
	t.Helper()
	resp, err := http.Get("https://checkip.amazonaws.com")
	require.NoError(t, err)
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	return strings.TrimSpace(string(body))
}

// ---------- The test ----------

func TestPrivateEgressViaEdge(t *testing.T) {
	t.Parallel()

	// Run in the folder where your Terraform example lives (the test file should be next to main.tf)
	terraformDir := "../examples/private_egress_via_edge"

	// Generate an SSH keypair (private key used to SSH to both edge and private instance).
	privateKeyPEM, publicKeyOpenSSH := generateRSAKeyPair(t)

	// Get test-runner public IP so we can lock down admin access; Terratest will pass this to Terraform.
	myIP := getMyPublicIP(t)
	allowedAdminCIDR := fmt.Sprintf("%s/32", myIP)

	// Prepare Terraform options (pass the generated public key + allowed admin cidr)
	tfOpts := &terraform.Options{
		TerraformDir: terraformDir,
		Vars: map[string]interface{}{
			"admin_ssh_public_key": publicKeyOpenSSH,
			"allowed_admin_cidr":   allowedAdminCIDR,
		},
		EnvVars: map[string]string{
			// Respect AWS_* env vars from the environment; nothing special here.
		},
	}

	// Init & apply - destroy deferred
	terraform.InitAndApply(t, tfOpts)
	defer terraform.Destroy(t, tfOpts)

	// Grab outputs (these outputs must have been added to the example as instructed)
	edgePublicIP := terraform.Output(t, tfOpts, "edge_public_ip")
	edgeInstanceID := terraform.Output(t, tfOpts, "edge_instance_id")
	edgePrimaryNI := terraform.Output(t, tfOpts, "edge_primary_network_interface_id")
	privateInstanceIP := terraform.Output(t, tfOpts, "private_test_private_ip")
	privateInstanceID := terraform.Output(t, tfOpts, "private_test_instance_id")
	privateRouteTableID := terraform.Output(t, tfOpts, "private_route_table_id")
	vpcCIDR := terraform.Output(t, tfOpts, "vpc_cidr")

	// AWS region — allow override via env var; default to eu-central-1 as your examples use that
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = "eu-central-1"
	}

	// 1) Check: edge instance SourceDestCheck = false
	sess := session.Must(session.NewSession(&aws.Config{Region: aws.String(region)}))
	ec2Client := ec2.New(sess)

	descIn := &ec2.DescribeInstancesInput{InstanceIds: []*string{aws.String(edgeInstanceID)}}
	descOut, err := ec2Client.DescribeInstances(descIn)
	require.NoError(t, err)
	require.Greater(t, len(descOut.Reservations), 0, "no reservation for edge instance")
	require.Greater(t, len(descOut.Reservations[0].Instances), 0, "no instance data for edge instance")
	edgeInstance := descOut.Reservations[0].Instances[0]

	// Assert source_dest_check == false
	require.NotNil(t, edgeInstance.SourceDestCheck, "SourceDestCheck should be present")
	require.Equal(t, false, aws.BoolValue(edgeInstance.SourceDestCheck), "edge.SourceDestCheck must be false for NAT instance")

	// 2) Check: private route table has 0.0.0.0/0 -> edge (either instance_id or network_interface_id)
	rtOut, err := ec2Client.DescribeRouteTables(&ec2.DescribeRouteTablesInput{RouteTableIds: []*string{aws.String(privateRouteTableID)}})
	require.NoError(t, err)
	require.Greater(t, len(rtOut.RouteTables), 0, "no private route table returned")

	found := false
	for _, r := range rtOut.RouteTables[0].Routes {
		if r.DestinationCidrBlock != nil && aws.StringValue(r.DestinationCidrBlock) == "0.0.0.0/0" {
			// check network_interface_id OR instance_id
			if (r.NetworkInterfaceId != nil && aws.StringValue(r.NetworkInterfaceId) == edgePrimaryNI) ||
				(r.InstanceId != nil && aws.StringValue(r.InstanceId) == edgeInstanceID) {
				found = true
			}
		}
	}
	require.True(t, found, "private route table should route 0.0.0.0/0 to the edge instance (instance_id or network_interface_id)")

	// Helper to run a command on edge with retries
	runOnEdge := func(cmd string) (string, error) {
		desc := fmt.Sprintf("ssh->edge run: %s", cmd)
		out, err := retry.DoWithRetryE(t, desc, 15, 10*time.Second, func() (string, error) {
			o, e := runSSHCommand(t, edgePublicIP, "ubuntu", privateKeyPEM, cmd)
			if e != nil {
				return "", e
			}
			return o, nil
		})
		return out, err
	}
    // 3) Check: iptables MASQUERADE exists on edge and matches VPC CIDR
    iptablesCmd := "sudo iptables -t nat -S | grep -i MASQUERADE || true"
    iptOut, err := runOnEdge(iptablesCmd)
    require.NoError(t, err, "failed to run iptables check on edge")
    require.Contains(t, iptOut, "MASQUERADE", "MASQUERADE rule must exist on edge")
    require.Contains(t, iptOut, vpcCIDR, "MASQUERADE rule must match VPC CIDR")



	// 4) From the private instance: curl https://api.github.com should succeed
	// -> We'll upload the private key to the edge temporarily and from edge SSH into the private instance (both instances share the same key)
	nestedScript := fmt.Sprintf(`cat > /tmp/testkey <<'EOF'
%s
EOF
chmod 600 /tmp/testkey
ssh -o StrictHostKeyChecking=no -i /tmp/testkey ubuntu@%s "sudo apt-get update -y && sudo apt-get install -y curl -y && curl -sI https://api.github.com | head -n 1"
`, privateKeyPEM, privateInstanceIP)

	curlOut, err := runOnEdge(nestedScript)
	require.NoError(t, err, "failed nested SSH from edge -> private to run curl")
	require.True(t, strings.Contains(curlOut, "200"), "expected HTTP 200 from https://api.github.com; got: %s", curlOut)

	// Done — test will defer terraform destroy
	t.Logf("Success: private instance (%s) reached internet via edge (%s).", privateInstanceID, edgeInstanceID)
}
