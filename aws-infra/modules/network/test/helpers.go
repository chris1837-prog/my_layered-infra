package test

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	gossh "golang.org/x/crypto/ssh"
	"github.com/stretchr/testify/require"
	"github.com/gruntwork-io/terratest/modules/retry"
	"net/http"
)

// ResolveKeyPath ensures we use an absolute path for the private key
func ResolveKeyPath(t *testing.T, keyPath string) string {
	t.Helper()
	absKeyFile, err := filepath.Abs(keyPath)
	require.NoError(t, err, "cannot resolve absolute path to private key")
	_, err = os.Stat(absKeyFile)
	require.NoError(t, err, "private key file does not exist")
	return absKeyFile
}

// RunSSHCommand runs `cmd` on host using username and private key file, returns combined stdout+stderr
func RunSSHCommand(t *testing.T, hostname, username, privateKeyFile, cmd string) (string, error) {
	t.Helper()

	keyBytes, err := os.ReadFile(privateKeyFile)
	require.NoError(t, err)

	signer, err := gossh.ParsePrivateKey(keyBytes)
	require.NoError(t, err)

	config := &gossh.ClientConfig{
		User:            username,
		Auth:            []gossh.AuthMethod{gossh.PublicKeys(signer)},
		HostKeyCallback: gossh.InsecureIgnoreHostKey(),
		Timeout:         30 * time.Second,
	}

	client, err := gossh.Dial("tcp", fmt.Sprintf("%s:22", hostname), config)
	require.NoError(t, err)
	defer client.Close()

	session, err := client.NewSession()
	require.NoError(t, err)
	defer session.Close()

	var combined strings.Builder
	session.Stdout = &combined
	session.Stderr = &combined

	err = session.Run(cmd)
	return combined.String(), err
}

// RetrySSHCommand wraps RunSSHCommand with retries
func RetrySSHCommand(t *testing.T, hostname, username, privateKeyFile, cmd string) (string, error) {
	t.Helper()
	return retry.DoWithRetryE(t,
		fmt.Sprintf("ssh->%s run: %s", hostname, cmd),
		15, 10*time.Second,
		func() (string, error) {
			return RunSSHCommand(t, hostname, username, privateKeyFile, cmd)
		})
}

// RunSSHViaEdge runs a command on a private instance through the edge (jump host)
func RunSSHViaEdge(t *testing.T, edgeHost, privateHost, username, keyFile, cmd string) (string, error) {
	t.Helper()

	keyBytes, err := os.ReadFile(keyFile)
	require.NoError(t, err)

	signer, err := gossh.ParsePrivateKey(keyBytes)
	require.NoError(t, err)

	edgeConfig := &gossh.ClientConfig{
		User:            username,
		Auth:            []gossh.AuthMethod{gossh.PublicKeys(signer)},
		HostKeyCallback: gossh.InsecureIgnoreHostKey(),
		Timeout:         30 * time.Second,
	}

	// Connect to edge instance
	edgeClient, err := gossh.Dial("tcp", fmt.Sprintf("%s:22", edgeHost), edgeConfig)
	require.NoError(t, err)
	defer edgeClient.Close()

	// Dial TCP from edge to private instance
	conn, err := edgeClient.Dial("tcp", fmt.Sprintf("%s:22", privateHost))
	require.NoError(t, err)

	// Create a new SSH client over the connection to the private instance
	ncc, chans, reqs, err := gossh.NewClientConn(conn, privateHost+":22", edgeConfig)
	require.NoError(t, err)
	privateClient := gossh.NewClient(ncc, chans, reqs)
	defer privateClient.Close()

	// Open session on private instance
	session, err := privateClient.NewSession()
	require.NoError(t, err)
	defer session.Close()

	var combined strings.Builder
	session.Stdout = &combined
	session.Stderr = &combined

	err = session.Run(cmd)
	return combined.String(), err
}

// RetrySSHViaEdge wraps RunSSHViaEdge with retries
func RetrySSHViaEdge(t *testing.T, edgeHost, privateHost, username, keyFile, cmd string) (string, error) {
	t.Helper()
	return retry.DoWithRetryE(t,
		fmt.Sprintf("ssh->%s->%s run: %s", edgeHost, privateHost, cmd),
		20, 30*time.Second,
		func() (string, error) {
			return RunSSHViaEdge(t, edgeHost, privateHost, username, keyFile, cmd)
		})
}

// GetMyPublicIP returns the public IP of the machine running the tests
func GetMyPublicIP(t *testing.T) string {
	t.Helper()
	resp, err := http.Get("https://checkip.amazonaws.com")
	require.NoError(t, err)
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	return strings.TrimSpace(string(body))
}

