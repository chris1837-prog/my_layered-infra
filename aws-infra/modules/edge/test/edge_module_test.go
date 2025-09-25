package test

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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
	rawRendered := terraform.Output(t, terraformOptions, "edge_user_data_raw")
	// Attempt base64 decode then gzip decompress to show beginning of cloud-config for diagnostics
	if rawRendered != "" {
		decoded, err := base64.StdEncoding.DecodeString(rawRendered)
		if err != nil {
			t.Logf("[WARN] Failed base64 decode of rendered user-data: %v", err)
		} else {
			zr, err := gzip.NewReader(bytes.NewReader(decoded))
			if err != nil {
				t.Logf("[WARN] Failed to create gzip reader for rendered user-data: %v", err)
			} else {
				defer zr.Close()
				var buf bytes.Buffer
				_, _ = io.CopyN(&buf, zr, 32*1024) // limit to first 32KB
				text := buf.String()
				// Provide preview capped
				preview := text
				if len(preview) > 800 {
					preview = preview[:800]
				}
				lines := strings.Split(preview, "\n")
				if len(lines) > 40 {
					lines = lines[:40]
				}
				preview = strings.Join(lines, "\n")
				t.Logf("[DEBUG] Decoded user-data preview (first ~40 lines / 800 chars):\n%s", preview)
			}
		}
	}
	// New: Get split-horizon registry URLs
	registryExternalURL := terraform.Output(t, terraformOptions, "registry_external_url")
	registryInternalURL := terraform.Output(t, terraformOptions, "registry_internal_url")
	primaryDomain := terraform.Output(t, terraformOptions, "primary_domain")
	t.Logf("[INFO] Registry External URL: %s", registryExternalURL)
	t.Logf("[INFO] Registry Internal URL: %s", registryInternalURL)
	t.Logf("[INFO] Primary Domain: %s", primaryDomain)
	registryExternalHost := strings.Split(strings.TrimPrefix(registryExternalURL, "https://"), "/")[0]
	registryInternalHost := strings.Split(strings.TrimPrefix(registryInternalURL, "https://"), "/")[0]

	// ------------------------------------------------------------------
	// DNS Readiness Pre-Check
	// Fail early (before long ACME wait loops) if required public DNS A
	// records are missing or not pointing at the edge public IP. This
	// guards against wasting 5-10 minutes waiting for certificates
	// when delegation or A records haven't propagated.
	// ------------------------------------------------------------------
	{
		// Override modes via EDGE_DNS_READINESS_MODE:
		//   strict (default): fail test immediately on missing/mismatched DNS
		//   warn:   emit warning and continue (ACME may later fail)
		//   skip:   skip DNS readiness entirely
		mode := strings.ToLower(strings.TrimSpace(os.Getenv("EDGE_DNS_READINESS_MODE")))
		if mode == "" {
			mode = "strict"
		}
		if mode == "skip" {
			t.Log("[INFO] Skipping DNS readiness check due to EDGE_DNS_READINESS_MODE=skip (expect ACME to potentially fail if delegation missing)")
		} else {
			lookupTargets := map[string]string{
				"primary domain":         primaryDomain,
				"external registry host": registryExternalHost,
			}
			for label, host := range lookupTargets {
				if host == "" {
					continue
				}
				// Retry resolution for up to 2 minutes (propagation or test env DNS cache)
				maxDNSAttempts := 24
				var resolved []string
				for i := 0; i < maxDNSAttempts; i++ {
					ips, err := net.LookupHost(host)
					if err == nil && len(ips) > 0 {
						resolved = ips
						break
					}
					time.Sleep(5 * time.Second)
				}
				if len(resolved) == 0 {
					msg := fmt.Sprintf("DNS readiness check failed: could not resolve %s '%s' after retries. Ensure NS delegation for the environment subdomain is in place and that an 'A' record for %s exists pointing to %s.", label, host, host, publicIP)
					if mode == "warn" {
						t.Log("[WARN] " + msg + " (continuing due to EDGE_DNS_READINESS_MODE=warn)")
						continue
					}
					t.Fatal(msg)
				}
				// Check whether any resolved IP matches the edge public IP; if not, warn (but fail to be strict)
				match := false
				for _, ip := range resolved {
					if ip == publicIP {
						match = true
						break
					}
				}
				if !match {
					msg := fmt.Sprintf("DNS readiness mismatch for %s '%s': resolved to %v but expected %s. Update the A record or wait for propagation.", label, host, resolved, publicIP)
					if mode == "warn" {
						t.Log("[WARN] " + msg + " (continuing due to EDGE_DNS_READINESS_MODE=warn)")
						continue
					}
					t.Fatal(msg)
				}
				t.Logf("\u001b[1;32m✅ [SUCCESS]\u001b[0m DNS readiness: %s '%s' -> %v (includes edge IP)", label, host, resolved)
			}
		}
	}

	// Feature flags for optional extended tests
	extClientEnabled := os.Getenv("EDGE_TEST_EXTERNAL_CLIENT") == "1" || strings.EqualFold(os.Getenv("EDGE_TEST_EXTERNAL_CLIENT"), "true")
	dockerHubEnabled := os.Getenv("EDGE_E2E_DOCKERHUB") == "1" || strings.EqualFold(os.Getenv("EDGE_E2E_DOCKERHUB"), "true")

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
			t.Log("\033[1;31m❌ [FAIL]\033[0m SSH not available within retry window")
			t.Fatalf("SSH not available after retries: %v", err)
		}
		time.Sleep(sleepBetweenRetries)
	}

	t.Log("\033[1;34m[INFO]\033[0m Polling for cloud-init completion signal...")
	maxWait := 300 // seconds (5 min max)
	pollInterval := 10 * time.Second
	found := false
	for i := 0; i < maxWait/int(pollInterval.Seconds()); i++ {
		out, err := ssh.CheckSshCommandE(t, host, "if [ -f /var/lib/cloud/instance/cloud-init-finished ]; then echo done; elif [ -f /var/lib/cloud/instance/cloud-init-failed ]; then echo failed; else echo notyet; fi")
		if err != nil {
			t.Logf("SSH command error while polling: %v", err)
		} else if strings.TrimSpace(out) == "done" {
			found = true
			t.Log("[SUCCESS] Cloud-init finished signal detected.")
			break
		} else if strings.TrimSpace(out) == "failed" {
			t.Log("\u274c [FAIL] Cloud-init failure marker detected; dumping logs...")
			out1, _ := ssh.CheckSshCommandE(t, host, "sudo tail -n 120 /var/log/cloud-init-output.log || true")
			out2, _ := ssh.CheckSshCommandE(t, host, "sudo tail -n 120 /var/log/cloud-init.log || true")
			out3, _ := ssh.CheckSshCommandE(t, host, "sudo tail -n 200 /var/log/edge-init.log || true")
			t.Log("--- cloud-init-output.log (tail) ---\n" + out1)
			t.Log("--- cloud-init.log (tail) ---\n" + out2)
			t.Log("--- edge-init.log (tail) ---\n" + out3)
			t.Fatalf("Cloud-init failed; see above logs")
		}
		t.Logf("Still waiting for cloud-init... (%d/%d)", i+1, maxWait/int(pollInterval.Seconds()))
		time.Sleep(pollInterval)
	}
	if !found {
		// Gather diagnostics before failing
		t.Log("\\033[1;33m[WARN]\\033[0m Cloud-init marker not found; collecting logs...")
		out1, _ := ssh.CheckSshCommandE(t, host, "sudo tail -n 120 /var/log/cloud-init-output.log || true")
		out2, _ := ssh.CheckSshCommandE(t, host, "sudo tail -n 120 /var/log/cloud-init.log || true")
		out3, _ := ssh.CheckSshCommandE(t, host, "test -f /opt/startup.sh && echo exists || echo missing")
		out4, _ := ssh.CheckSshCommandE(t, host, "sudo bash -n /opt/startup.sh >/dev/null 2>&1 && echo syntax-ok || echo syntax-error")
		t.Logf("/opt/startup.sh: %s, syntax: %s", strings.TrimSpace(out3), strings.TrimSpace(out4))
		t.Log("--- cloud-init-output.log (tail) ---\n" + out1)
		t.Log("--- cloud-init.log (tail) ---\n" + out2)
		t.Log("\033[1;31m❌ [FAIL]\033[0m Cloud-init did not finish in time")
		t.Fatalf("Cloud-init did not finish within %d seconds", maxWait)
	}

	t.Log("\033[1;34m[INFO]\033[0m Checking Docker installation...")
	dockerVersionCmd := "docker --version"
	dockerVersionOut, err := ssh.CheckSshCommandE(t, host, dockerVersionCmd)
	if err != nil {
		t.Logf("\033[1;31m❌ [FAIL]\033[0m Docker not available: %v", err)
	}
	require.NoError(t, err, "Docker should be installed and available in PATH")
	t.Logf("Docker version: %s", strings.TrimSpace(dockerVersionOut))
	t.Log("\033[1;32m✅ [SUCCESS]\033[0m Docker is installed and available")

	// --- Docker Registry & Caddy Tests ---
	t.Log("\033[1;34m[INFO]\033[0m Checking Docker registry container...")
	regPsCmd := "sudo docker ps --format '{{.Image}}'"
	regPsOut, err := ssh.CheckSshCommandE(t, host, regPsCmd)
	require.NoError(t, err, "Failed to list running Docker containers")
	containsReg := strings.Contains(regPsOut, "registry:2")
	if containsReg {
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m Docker registry container is running")
	} else {
		t.Log("\033[1;31m❌ [FAIL]\033[0m Docker registry container not running")
	}
	assert.Contains(t, regPsOut, "registry:2", "Docker registry container should be running")

	t.Log("\033[1;34m[INFO]\033[0m Checking Caddyfile for registry domains...")
	caddyfileCmd := "sudo cat /etc/caddy/Caddyfile"
	caddyfileOut, err := ssh.CheckSshCommandE(t, host, caddyfileCmd)
	assert.NoError(t, err)
	assert.Contains(t, caddyfileOut, strings.TrimPrefix(registryExternalURL, "https://"), "Caddyfile should contain the external registry domain")
	assert.Contains(t, caddyfileOut, strings.TrimPrefix(registryInternalURL, "https://"), "Caddyfile should contain the internal registry domain")
	t.Log("\033[1;32m✅ [SUCCESS]\033[0m Caddyfile contains both registry domains")

	t.Log("\033[1;34m[INFO]\033[0m Validating Caddy configuration...")
	caddyValidateCmd := "sudo caddy validate --config /etc/caddy/Caddyfile"
	caddyValidateOut, err := ssh.CheckSshCommandE(t, host, caddyValidateCmd)
	if err != nil {
		t.Logf("\033[1;31m❌ [FAIL]\033[0m Caddy validate failed: %v", err)
	}
	require.NoError(t, err, "Caddy configuration should validate")
	t.Logf("Caddy validate output: %s", strings.TrimSpace(caddyValidateOut))
	t.Log("\033[1;32m✅ [SUCCESS]\033[0m Caddy configuration is valid")

	t.Log("\033[1;34m[INFO]\033[0m Checking htpasswd file for registry user...")
	htpasswdCmd := "sudo cat /opt/registry/auth/htpasswd"
	// We'll assert against the actual username extracted below once available

	// --- Registry HTTP Auth Validation via Caddy (curl) ---
	t.Log("\033[1;34m[INFO]\033[0m Testing registry HTTP endpoints without auth (should be 401) for both domains...")
	for _, h := range []string{registryExternalHost, registryInternalHost} {
		curlNoAuthCmd := fmt.Sprintf("curl -s -k -D - -o /dev/null --resolve '%s:443:127.0.0.1' https://%s/v2/", h, h)
		headersNoAuth, err := ssh.CheckSshCommandE(t, host, curlNoAuthCmd)
		require.NoError(t, err)
		assert.Contains(t, headersNoAuth, " 401", "Unauthenticated request should return 401 for "+h)
	}

	t.Log("\033[1;34m[INFO]\033[0m Extracting registry credentials from startup script for auth test...")
	// Extract "user:pass" from the htpasswd creation line in /opt/startup.sh
	extractCredsCmd := `awk 'match($0, /-Bbn "([^"]+)" "([^"]+)"/, a) {print a[1] ":" a[2]; exit}' /opt/startup.sh 2>/dev/null`
	creds, err := ssh.CheckSshCommandE(t, host, extractCredsCmd)
	require.NoError(t, err, "Failed to extract registry credentials from startup.sh")
	creds = strings.TrimSpace(creds)
	require.NotEmpty(t, creds, "Extracted credentials should not be empty")
	parts := strings.SplitN(creds, ":", 2)
	require.Equal(t, 2, len(parts), "Credentials should be in user:pass format")
	regUser := parts[0]
	regPass := parts[1]
	// Shell-escape user:pass for single-quoted context: replace ' with '\'' pattern (i.e., '"'"')
	shSingleQuote := func(s string) string { return "'" + strings.ReplaceAll(s, "'", `'"'"'`) + "'" }
	authEscaped := shSingleQuote(regUser + ":" + regPass)
	t.Log("\033[1;32m✅ [SUCCESS]\033[0m Extracted registry credentials for testing")

	t.Log("\033[1;34m[INFO]\033[0m Testing registry HTTP endpoint with wrong creds (should be 401)...")
	wrongAuth := shSingleQuote(regUser + ":" + "wrongpassword")
	for _, h := range []string{registryExternalHost, registryInternalHost} {
		curlWrongAuthCmd := fmt.Sprintf("curl -s -k -o /dev/null -w '%%{http_code}' --resolve '%s:443:127.0.0.1' -u %s https://%s/v2/", h, wrongAuth, h)
		httpCodeWrongResp, err := ssh.CheckSshCommandE(t, host, curlWrongAuthCmd)
		require.NoError(t, err)
		assert.Equal(t, "401", strings.TrimSpace(httpCodeWrongResp), "Wrong credentials should return 401 for "+h)
	}
	t.Log("\033[1;32m✅ [SUCCESS]\033[0m Wrong credentials return 401 as expected for both domains")

	t.Log("\033[1;34m[INFO]\033[0m Testing registry HTTP endpoint with correct creds (should be 200)...")
	for _, h := range []string{registryExternalHost, registryInternalHost} {
		curlGoodAuthCmd := fmt.Sprintf("curl -s -k -o /dev/null -w '%%{http_code}' --resolve '%s:443:127.0.0.1' -u %s https://%s/v2/", h, authEscaped, h)
		httpCodeGoodResp, err := ssh.CheckSshCommandE(t, host, curlGoodAuthCmd)
		require.NoError(t, err)
		assert.Equal(t, "200", strings.TrimSpace(httpCodeGoodResp), "Correct credentials should return 200 for "+h)
	}
	t.Log("\033[1;32m✅ [SUCCESS]\033[0m Authenticated request returns 200 as expected for both domains")

	// Validate htpasswd contains the actual registry username
	htpasswdOut2, err := ssh.CheckSshCommandE(t, host, htpasswdCmd)
	assert.NoError(t, err)
	if !strings.Contains(htpasswdOut2, regUser) {
		t.Log("\033[1;31m❌ [FAIL]\033[0m htpasswd missing registry user entry")
	}
	assert.Contains(t, htpasswdOut2, regUser, "htpasswd file should contain the registry user")
	if strings.Contains(htpasswdOut2, regUser) {
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m htpasswd contains the registry user entry")
	}

	// --- Docker login/push/pull smoke test ---
	// Ensure Docker trusts the Caddy internal CA for the registry domain
	t.Log("\033[1;34m[INFO]\033[0m Verifying Docker trust store contains Caddy internal CA...")
	for _, h := range []string{registryExternalHost, registryInternalHost} {
		caCheckCmd := fmt.Sprintf("test -f /etc/docker/certs.d/%s/ca.crt && echo present || echo missing", h)
		caStatus, _ := ssh.CheckSshCommandE(t, host, caCheckCmd)
		caCheckCmd443 := fmt.Sprintf("test -f /etc/docker/certs.d/%s:443/ca.crt && echo present || echo missing", h)
		caStatus443, _ := ssh.CheckSshCommandE(t, host, caCheckCmd443)
		if strings.TrimSpace(caStatus) != "present" && strings.TrimSpace(caStatus443) != "present" {
			t.Logf("\033[1;31m❌ [FAIL]\033[0m Docker trust store missing CA for %s (both plain host and :443)", h)
		} else {
			t.Logf("\033[1;32m✅ [SUCCESS]\033[0m Docker trust store has CA for %s (host: %s, host:443: %s)", h, strings.TrimSpace(caStatus), strings.TrimSpace(caStatus443))
		}
	}

	// Login
	t.Log("\033[1;34m[INFO]\033[0m Docker login to registry via Caddy...")
	loginCmd := fmt.Sprintf("echo %s | docker login %s -u %s --password-stdin", shSingleQuote(regPass), registryExternalHost, shSingleQuote(regUser))
	loginOut, err := ssh.CheckSshCommandE(t, host, loginCmd)
	if err != nil || !strings.Contains(loginOut, "Login Succeeded") {
		t.Logf("\033[1;31m❌ [FAIL]\033[0m Docker login attempt failed. Output: %s Error: %v", loginOut, err)
		t.Log("\033[1;34m[INFO]\033[0m Retrying docker login once after short delay...")
		retryLoginCmd := fmt.Sprintf("sleep 3; %s", loginCmd)
		loginOut, err = ssh.CheckSshCommandE(t, host, retryLoginCmd)
	}
	if err != nil || !strings.Contains(loginOut, "Login Succeeded") {
		// Print permissions diagnostics to help debug issues like permission denied on CA files
		diag1, _ := ssh.CheckSshCommandE(t, host, fmt.Sprintf("ls -ld /etc/docker/certs.d /etc/docker/certs.d/%s /etc/docker/certs.d/%s:443 || true", registryExternalHost, registryExternalHost))
		diag2, _ := ssh.CheckSshCommandE(t, host, fmt.Sprintf("ls -l /etc/docker/certs.d/%s 2>/dev/null || true", registryExternalHost))
		diag3, _ := ssh.CheckSshCommandE(t, host, fmt.Sprintf("ls -l /etc/docker/certs.d/%s:443 2>/dev/null || true", registryExternalHost))
		whoami, _ := ssh.CheckSshCommandE(t, host, "id")
		t.Log("--- certs dirs (ls -ld) ---\n" + diag1)
		t.Log("--- certs host (ls -l) ---\n" + diag2)
		t.Log("--- certs host:443 (ls -l) ---\n" + diag3)
		t.Log("--- user id ---\n" + whoami)
		if err != nil {
			t.Logf("\033[1;31m❌ [FAIL]\033[0m Docker login command failed: %v", err)
		}
	}
	require.NoError(t, err, "Docker login should succeed")
	if !strings.Contains(loginOut, "Login Succeeded") {
		t.Log("\033[1;31m❌ [FAIL]\033[0m Docker login did not report success")
	}
	assert.Contains(t, loginOut, "Login Succeeded", "Docker login should report success")
	if strings.Contains(loginOut, "Login Succeeded") {
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m Docker login succeeded")
	}

	// Select a local image to avoid external network dependency
	t.Log("\033[1;34m[INFO]\033[0m Selecting local image for push (prefer busybox:latest if present; fallback to registry:2)...")
	checkBusyboxCmd := "docker image inspect busybox:latest >/dev/null 2>&1 && echo present || echo missing"
	busyboxStatus, _ := ssh.CheckSshCommandE(t, host, checkBusyboxCmd)
	baseImage := ""
	if strings.TrimSpace(busyboxStatus) == "present" {
		baseImage = "busybox:latest"
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m Using local busybox:latest image")
	} else {
		baseImage = "registry:2"
		t.Log("\033[1;33m[WARN]\033[0m busybox:latest not present locally; using registry:2 as test image")
	}

	// Tag and push to registry
	baseName := strings.SplitN(baseImage, ":", 2)[0]
	// Use external host for push/pull smoke test (internal will behave the same locally)
	imageName := fmt.Sprintf("%s/test/%s:tt", registryExternalHost, baseName)
	t.Log("\033[1;34m[INFO]\033[0m Tagging test image for registry push...")
	tagCmd := fmt.Sprintf("docker tag %s %s 2>&1 || (echo '[WARN] direct tag failed, trying container image ID...' && img=$(docker inspect --format '{{.Image}}' registry 2>/dev/null || true) && if [ -n \"$img\" ]; then docker tag $img %s; else exit 1; fi)", baseImage, imageName, imageName)
	tagOut, err := ssh.CheckSshCommandE(t, host, tagCmd)
	if err != nil {
		// Diagnostics on failure
		imgs, _ := ssh.CheckSshCommandE(t, host, "docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' || true")
		who, _ := ssh.CheckSshCommandE(t, host, "id || true")
		sock, _ := ssh.CheckSshCommandE(t, host, "ls -l /var/run/docker.sock || true")
		t.Log("--- docker tag output ---\n" + tagOut)
		t.Log("--- docker images ---\n" + imgs)
		t.Log("--- user id ---\n" + who)
		t.Log("--- docker.sock perms ---\n" + sock)
		t.Logf("\033[1;31m❌ [FAIL]\033[0m Docker tag failed: %v", err)
	}
	require.NoError(t, err, "Should tag image for push")
	t.Log("\033[1;32m✅ [SUCCESS]\033[0m Tagged image")

	t.Log("\033[1;34m[INFO]\033[0m Pushing test image to registry...")
	pushOut, err := ssh.CheckSshCommandE(t, host, fmt.Sprintf("docker push %s", imageName))
	require.NoError(t, err, "Docker push should succeed")
	lowerPush := strings.ToLower(pushOut)
	// Consider push successful if:
	// - output contains any case of "pushed" (layer lines)
	// - or "mounted from" (already present at registry)
	// - or a digest line like "<tag>: digest: sha256:..." (tag-agnostic)
	if strings.Contains(lowerPush, "pushed") || strings.Contains(lowerPush, "mounted from") || strings.Contains(pushOut, "digest: sha256:") {
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m Docker push reported success")
	} else {
		t.Log(pushOut)
		require.Fail(t, "Docker push did not report success")
	}

	// Remove local tag and pull back from registry
	t.Log("\033[1;34m[INFO]\033[0m Removing local image and pulling back from registry...")
	_, _ = ssh.CheckSshCommandE(t, host, fmt.Sprintf("docker rmi -f %s || true", imageName))
	pullBackOut, err := ssh.CheckSshCommandE(t, host, fmt.Sprintf("docker pull %s", imageName))
	require.NoError(t, err, "Docker pull from registry should succeed")
	if strings.Contains(pullBackOut, "Downloaded newer image") || strings.Contains(pullBackOut, "Image is up to date") || strings.Contains(pullBackOut, "Status: Downloaded") {
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m Pulled image back from registry")
	} else {
		t.Log(pullBackOut)
		require.Fail(t, "Docker pull from registry did not report success")
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
