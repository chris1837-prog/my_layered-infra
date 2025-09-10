package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	gossh "golang.org/x/crypto/ssh"
	"github.com/gruntwork-io/terratest/modules/retry"
)

const cmdPreviewLen = 140

// --- small helpers -----------------------------------------------------------

func trimForLog(s string, n int) string {
	if len(s) <= n {
		return strings.TrimSpace(s)
	}
	return strings.TrimSpace(s[:n]) + "…"
}

// --- direct SSH with key content ---------------------------------------------

// RunSSHCommandWithKeyContent runs a command on host using SSH private key content (in memory)
func RunSSHCommandWithKeyContent(t *testing.T, hostname, username, privateKeyContent, cmd string) (string, error) {
	t.Helper()
	t.Logf("➡️  SSH connect %s@%s:22", username, hostname)

	signer, err := gossh.ParsePrivateKey([]byte(privateKeyContent))
	if err != nil {
		t.Fatalf("failed to parse private key: %v", err)
	}

	config := &gossh.ClientConfig{
		User:            username,
		Auth:            []gossh.AuthMethod{gossh.PublicKeys(signer)},
		HostKeyCallback: gossh.InsecureIgnoreHostKey(),
		Timeout:         30 * time.Second,
	}

	client, err := gossh.Dial("tcp", fmt.Sprintf("%s:22", hostname), config)
	if err != nil {
		t.Fatalf("failed to dial SSH: %v", err)
	}
	defer client.Close()
	t.Logf("✅ SSH connected to %s", hostname)

	session, err := client.NewSession()
	if err != nil {
		t.Fatalf("failed to create SSH session: %v", err)
	}
	defer session.Close()

	t.Logf("🖥️  Running on %s: %q", hostname, trimForLog(cmd, cmdPreviewLen))

	var combined strings.Builder
	session.Stdout = &combined
	session.Stderr = &combined

	err = session.Run(cmd)
	out := combined.String()

	if err != nil {
		t.Logf("❌ Command failed on %s: %v", hostname, err)
		t.Logf("⤵️  Output (preview): %s", trimForLog(out, 400))
	} else {
		t.Logf("✅ Command succeeded on %s", hostname)
		t.Logf("⤵️  Output (preview): %s", trimForLog(out, 400))
	}

	return out, err
}

// RetrySSHCommandWithKeyContent wraps RunSSHCommandWithKeyContent with retries
func RetrySSHCommandWithKeyContent(t *testing.T, hostname, username, privateKeyContent, cmd string) (string, error) {
	t.Helper()
	desc := fmt.Sprintf("ssh->%s run: %s", hostname, trimForLog(cmd, cmdPreviewLen))
	t.Logf("🔁 %s (with retries)", desc)

	return retry.DoWithRetryE(t, desc, 15, 10*time.Second, func() (string, error) {
		return RunSSHCommandWithKeyContent(t, hostname, username, privateKeyContent, cmd)
	})
}

// --- SSH via edge (tunneled) -------------------------------------------------

// RunSSHViaEdgeWithKeyContent runs a command on a private instance through the edge (jump host)
func RunSSHViaEdgeWithKeyContent(t *testing.T, edgeHost, privateHost, username, privateKeyContent, cmd string) (string, error) {
	t.Helper()
	t.Logf("➡️  SSH (edge) connect %s@%s:22", username, edgeHost)

	signer, err := gossh.ParsePrivateKey([]byte(privateKeyContent))
	if err != nil {
		t.Fatalf("failed to parse private key: %v", err)
	}

	edgeConfig := &gossh.ClientConfig{
		User:            username,
		Auth:            []gossh.AuthMethod{gossh.PublicKeys(signer)},
		HostKeyCallback: gossh.InsecureIgnoreHostKey(),
		Timeout:         30 * time.Second,
	}

	// Connect to edge instance
	edgeClient, err := gossh.Dial("tcp", fmt.Sprintf("%s:22", edgeHost), edgeConfig)
	if err != nil {
		t.Fatalf("failed to dial edge SSH: %v", err)
	}
	defer edgeClient.Close()
	t.Logf("✅ SSH connected to edge %s", edgeHost)

	// Dial TCP from edge to private instance
	t.Logf("🔌 Tunneling TCP from edge -> %s:22", privateHost)
	conn, err := edgeClient.Dial("tcp", fmt.Sprintf("%s:22", privateHost))
	if err != nil {
		t.Fatalf("failed to dial private host from edge: %v", err)
	}

	// SSH client over the connection to private instance
	ncc, chans, reqs, err := gossh.NewClientConn(conn, privateHost+":22", edgeConfig)
	if err != nil {
		t.Fatalf("failed to create tunneled SSH client connection: %v", err)
	}
	privateClient := gossh.NewClient(ncc, chans, reqs)
	defer privateClient.Close()
	t.Logf("✅ SSH tunneled client ready for %s", privateHost)

	// Open session on private instance
	session, err := privateClient.NewSession()
	if err != nil {
		t.Fatalf("failed to create session on private host: %v", err)
	}
	defer session.Close()

	t.Logf("🖥️  Running on %s via %s: %q", privateHost, edgeHost, trimForLog(cmd, cmdPreviewLen))

	var combined strings.Builder
	session.Stdout = &combined
	session.Stderr = &combined

	err = session.Run(cmd)
	out := combined.String()

	if err != nil {
		t.Logf("❌ Command failed on %s via %s: %v", privateHost, edgeHost, err)
		t.Logf("⤵️  Output (preview): %s", trimForLog(out, 400))
	} else {
		t.Logf("✅ Command succeeded on %s via %s", privateHost, edgeHost)
		t.Logf("⤵️  Output (preview): %s", trimForLog(out, 400))
	}

	return out, err
}

// RetrySSHViaEdgeWithKeyContent wraps RunSSHViaEdgeWithKeyContent with retries
func RetrySSHViaEdgeWithKeyContent(t *testing.T, edgeHost, privateHost, username, privateKeyContent, cmd string) (string, error) {
	t.Helper()
	desc := fmt.Sprintf("ssh->%s->%s run: %s", edgeHost, privateHost, trimForLog(cmd, cmdPreviewLen))
	t.Logf("🔁 %s (with retries)", desc)

	return retry.DoWithRetryE(t, desc, 20, 30*time.Second, func() (string, error) {
		return RunSSHViaEdgeWithKeyContent(t, edgeHost, privateHost, username, privateKeyContent, cmd)
	})
}

