package test

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	gossh "golang.org/x/crypto/ssh"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/stretchr/testify/require"
)

const cmdPreviewLen = 140

// --- small helpers -----------------------------------------------------------

func trimForLog(s string, n int) string {
	if len(s) <= n {
		return strings.TrimSpace(s)
	}
	return strings.TrimSpace(s[:n]) + "…"
}

// ResolveKeyPath ensures we use an absolute path for the private key
func ResolveKeyPath(t *testing.T, keyPath string) string {
	t.Helper()

	absKeyFile, err := filepath.Abs(keyPath)
	require.NoError(t, err, "cannot resolve absolute path to private key")

	info, err := os.Stat(absKeyFile)
	require.NoError(t, err, "private key file does not exist")

	t.Logf("🔐 Using SSH key: %s (size=%d bytes, mode=%s)", absKeyFile, info.Size(), info.Mode())
	return absKeyFile
}

// --- direct SSH --------------------------------------------------------------

/*
RunSSHCommand runs `cmd` on host using username and private key file,
returning combined stdout+stderr.
*/
func RunSSHCommand(t *testing.T, hostname, username, privateKeyFile, cmd string) (string, error) {
	t.Helper()

	t.Logf("➡️  SSH connect %s@%s:22", username, hostname)

	keyBytes, err := os.ReadFile(privateKeyFile)
	require.NoError(t, err, "failed to read private key file")

	signer, err := gossh.ParsePrivateKey(keyBytes)
	require.NoError(t, err, "failed to parse private key")

	config := &gossh.ClientConfig{
		User:            username,
		Auth:            []gossh.AuthMethod{gossh.PublicKeys(signer)},
		HostKeyCallback: gossh.InsecureIgnoreHostKey(),
		Timeout:         30 * time.Second,
	}

	client, err := gossh.Dial("tcp", fmt.Sprintf("%s:22", hostname), config)
	require.NoError(t, err, "failed to dial SSH")
	defer client.Close()
	t.Logf("✅ SSH connected to %s", hostname)

	session, err := client.NewSession()
	require.NoError(t, err, "failed to create SSH session")
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

// RetrySSHCommand wraps RunSSHCommand with retries and descriptive logging
func RetrySSHCommand(t *testing.T, hostname, username, privateKeyFile, cmd string) (string, error) {
	t.Helper()
	desc := fmt.Sprintf("ssh->%s run: %s", hostname, trimForLog(cmd, cmdPreviewLen))
	t.Logf("🔁 %s (with retries)", desc)

	return retry.DoWithRetryE(t, desc, 15, 10*time.Second, func() (string, error) {
		return RunSSHCommand(t, hostname, username, privateKeyFile, cmd)
	})
}

// --- SSH via edge (tunneled) -------------------------------------------------

/*
RunSSHViaEdge runs a command on a private instance through the edge (jump host),
without requiring ProxyJump support on the local machine.
*/
func RunSSHViaEdge(t *testing.T, edgeHost, privateHost, username, keyFile, cmd string) (string, error) {
	t.Helper()

	t.Logf("➡️  SSH (edge) connect %s@%s:22", username, edgeHost)

	keyBytes, err := os.ReadFile(keyFile)
	require.NoError(t, err, "failed to read private key file")

	signer, err := gossh.ParsePrivateKey(keyBytes)
	require.NoError(t, err, "failed to parse private key")

	edgeConfig := &gossh.ClientConfig{
		User:            username,
		Auth:            []gossh.AuthMethod{gossh.PublicKeys(signer)},
		HostKeyCallback: gossh.InsecureIgnoreHostKey(),
		Timeout:         30 * time.Second,
	}

	// Connect to edge instance
	edgeClient, err := gossh.Dial("tcp", fmt.Sprintf("%s:22", edgeHost), edgeConfig)
	require.NoError(t, err, "failed to dial edge SSH")
	defer edgeClient.Close()
	t.Logf("✅ SSH connected to edge %s", edgeHost)

	// Dial TCP from edge to private instance
	t.Logf("🔌 Tunneling TCP from edge -> %s:22", privateHost)
	conn, err := edgeClient.Dial("tcp", fmt.Sprintf("%s:22", privateHost))
	require.NoError(t, err, "failed to dial private host from edge")

	// Create a new SSH client over the connection to the private instance
	t.Logf("🔐 Establishing SSH client over tunnel to %s", privateHost)
	ncc, chans, reqs, err := gossh.NewClientConn(conn, privateHost+":22", edgeConfig)
	require.NoError(t, err, "failed to create tunneled SSH client connection")
	privateClient := gossh.NewClient(ncc, chans, reqs)
	defer privateClient.Close()
	t.Logf("✅ SSH tunneled client ready for %s", privateHost)

	// Open session on private instance
	session, err := privateClient.NewSession()
	require.NoError(t, err, "failed to create session on private host")
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

// RetrySSHViaEdge wraps RunSSHViaEdge with retries and descriptive logging
func RetrySSHViaEdge(t *testing.T, edgeHost, privateHost, username, keyFile, cmd string) (string, error) {
	t.Helper()
	desc := fmt.Sprintf("ssh->%s->%s run: %s", edgeHost, privateHost, trimForLog(cmd, cmdPreviewLen))
	t.Logf("🔁 %s (with retries)", desc)

	return retry.DoWithRetryE(t, desc, 20, 30*time.Second, func() (string, error) {
		return RunSSHViaEdge(t, edgeHost, privateHost, username, keyFile, cmd)
	})
}

// GetMyPublicIP returns the public IP of the machine running the tests
func GetMyPublicIP(t *testing.T) string {
	t.Helper()
	resp, err := http.Get("https://checkip.amazonaws.com")
	require.NoError(t, err, "failed to reach checkip service")
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err, "failed to read checkip response")
	ip := strings.TrimSpace(string(body))
	t.Logf("🌍 Detected local public IP: %s", ip)
	return ip
}

