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
		err = ssh.CheckSshConnectionE(t, host)
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

	t.Log("\033[1;34m[INFO]\033[0m Waiting for edge init to finish (edge-init-finished marker)...")
	maxWait := 210 // reduced from 300 now that provisioning is stable
	pollInterval := 10 * time.Second
	found := false
	diagEvery := 6 // collect diagnostics every N polls (~1 minute)
	for i := 0; i < maxWait/int(pollInterval.Seconds()); i++ {
		// Also treat native cloud-init completion as success even if our custom marker missing
		markerCmd := strings.Join([]string{
			"if [ -f /var/lib/cloud/instance/edge-init-finished ]; then echo custom-done;",
			"elif [ -f /var/lib/cloud/instance/cloud-init-failed ]; then echo failed;",
			"elif [ -f /var/lib/cloud/instance/boot-finished ]; then echo native-done;",
			"else echo notyet; fi",
		}, " ")
		out, err := ssh.CheckSshCommandE(t, host, markerCmd)
		state := strings.TrimSpace(out)
		if err != nil {
			t.Logf("SSH command error while polling: %v", err)
		}
		if state == "custom-done" || state == "native-done" {
			found = true
			if state == "custom-done" {
				t.Log("[SUCCESS] Custom cloud-init marker detected.")
			} else {
				t.Log("[SUCCESS] Native cloud-init boot-finished marker detected (custom marker absent).")
				// Collect immediate diagnostics because our startup script did not apparently run
				bootcmdLog, _ := ssh.CheckSshCommandE(t, host, "sudo ls -l /var/log/edge-bootcmd.log 2>/dev/null || echo missing")
				preLog, _ := ssh.CheckSshCommandE(t, host, "sudo ls -l /var/log/edge-userdata-pre.log 2>/dev/null || echo missing")
				runcmdLog, _ := ssh.CheckSshCommandE(t, host, "sudo ls -l /var/log/edge-debug.log 2>/dev/null || echo missing")
				startupExists, _ := ssh.CheckSshCommandE(t, host, "test -f /opt/startup.sh && echo exists || echo missing")
				startupSvc, _ := ssh.CheckSshCommandE(t, host, "sudo ls -l /etc/systemd/system/edge-startup.service 2>/dev/null || echo missing")
				cloudInitOut, _ := ssh.CheckSshCommandE(t, host, "sudo head -n 80 /var/log/cloud-init-output.log 2>/dev/null || true")
				cloudInitLog, _ := ssh.CheckSshCommandE(t, host, "sudo grep -n 'runcmd' /var/log/cloud-init.log 2>/dev/null | tail -n 40 || true")
				cloudInitBoot, _ := ssh.CheckSshCommandE(t, host, "sudo grep -n 'bootcmd' /var/log/cloud-init.log 2>/dev/null | tail -n 40 || true")
				cloudInitStages, _ := ssh.CheckSshCommandE(t, host, "cloud-init status --long 2>/dev/null || true")
				unameOut, _ := ssh.CheckSshCommandE(t, host, "uname -a || true")
				osRelease, _ := ssh.CheckSshCommandE(t, host, "cat /etc/os-release 2>/dev/null | head -n 12 || true")
				aptVersion, _ := ssh.CheckSshCommandE(t, host, "apt --version 2>/dev/null | head -n 1 || echo 'apt-missing'")
				t.Log("[DIAG-IMMEDIATE] edge-bootcmd.log: " + strings.TrimSpace(bootcmdLog))
				t.Log("[DIAG-IMMEDIATE] edge-userdata-pre.log: " + strings.TrimSpace(preLog))
				t.Log("[DIAG-IMMEDIATE] edge-debug.log: " + strings.TrimSpace(runcmdLog))
				t.Log("[DIAG-IMMEDIATE] /opt/startup.sh: " + strings.TrimSpace(startupExists))
				t.Log("[DIAG-IMMEDIATE] edge-startup.service: " + strings.TrimSpace(startupSvc))
				t.Log("[DIAG-IMMEDIATE] uname -a: " + strings.TrimSpace(unameOut))
				t.Log("[DIAG-IMMEDIATE] /etc/os-release (partial):\n" + osRelease)
				t.Log("[DIAG-IMMEDIATE] apt version: " + strings.TrimSpace(aptVersion))
				t.Log("[DIAG-IMMEDIATE] cloud-init-output.log (head):\n" + cloudInitOut)
				t.Log("[DIAG-IMMEDIATE] cloud-init.log (runcmd excerpts):\n" + cloudInitLog)
				t.Log("[DIAG-IMMEDIATE] cloud-init.log (bootcmd excerpts):\n" + cloudInitBoot)
				t.Log("[DIAG-IMMEDIATE] cloud-init status --long:\n" + cloudInitStages)
				// If bootcmd and write_files artifacts missing, flag warning
				if strings.Contains(bootcmdLog, "missing") || strings.Contains(preLog, "missing") {
					t.Log("[WARN] Bootcmd or write_files artifacts missing: cloud-init may not have parsed user-data correctly.")
				}
			}
			break
		} else if state == "failed" {
			t.Log("\u274c [FAIL] Cloud-init failure marker detected; dumping logs...")
			collectAndLog := func() {
				out1, _ := ssh.CheckSshCommandE(t, host, "sudo tail -n 120 /var/log/cloud-init-output.log || true")
				out2, _ := ssh.CheckSshCommandE(t, host, "sudo tail -n 120 /var/log/cloud-init.log || true")
				out3, _ := ssh.CheckSshCommandE(t, host, "sudo tail -n 120 /var/log/edge-init.log || true")
				bootcmd, _ := ssh.CheckSshCommandE(t, host, "sudo cat /var/log/edge-bootcmd.log 2>/dev/null || true")
				prelog, _ := ssh.CheckSshCommandE(t, host, "sudo cat /var/log/edge-userdata-pre.log 2>/dev/null || true")
				dbglog, _ := ssh.CheckSshCommandE(t, host, "sudo cat /var/log/edge-debug.log 2>/dev/null || true")
				svc1, _ := ssh.CheckSshCommandE(t, host, "sudo systemctl status caddy --no-pager -l 2>/dev/null | tail -n 80 || true")
				reglog, _ := ssh.CheckSshCommandE(t, host, "sudo docker logs --tail 60 registry 2>/dev/null || true")
				t.Log("--- cloud-init-output.log (tail) ---\n" + out1)
				t.Log("--- cloud-init.log (tail) ---\n" + out2)
				t.Log("--- edge-init.log (tail) ---\n" + out3)
				t.Log("--- edge-bootcmd.log ---\n" + bootcmd)
				t.Log("--- edge-userdata-pre.log ---\n" + prelog)
				t.Log("--- edge-debug.log ---\n" + dbglog)
				t.Log("--- systemctl status caddy (tail) ---\n" + svc1)
				t.Log("--- docker logs registry (tail) ---\n" + reglog)
			}
			collectAndLog()
			t.Fatalf("Cloud-init failed; see above logs")
		}

		// Periodic mid-run diagnostics to understand where cloud-init is stuck
		if (i+1)%diagEvery == 0 {
			stageOut, _ := ssh.CheckSshCommandE(t, host, "cloud-init status 2>/dev/null || true")
			bootcmd, _ := ssh.CheckSshCommandE(t, host, "sudo cat /var/log/edge-bootcmd.log 2>/dev/null || true")
			prelog, _ := ssh.CheckSshCommandE(t, host, "sudo head -n 20 /var/log/edge-userdata-pre.log 2>/dev/null || true")
			dbglog, _ := ssh.CheckSshCommandE(t, host, "sudo head -n 20 /var/log/edge-debug.log 2>/dev/null || true")
			psApt, _ := ssh.CheckSshCommandE(t, host, "ps -eo pid,cmd | egrep 'apt|dpkg|cloud-init' | grep -v egrep || true")
			memFree, _ := ssh.CheckSshCommandE(t, host, "free -h || true")
			space, _ := ssh.CheckSshCommandE(t, host, "df -h / || true")
			errTail := ""
			if strings.Contains(strings.ToLower(stageOut), "error") {
				errTail, _ = ssh.CheckSshCommandE(t, host, "grep -i 'error' /var/log/cloud-init.log | tail -n 20 || true")
			}
			t.Logf("[DIAG] poll=%d state=%s cloud-init-status='%s'", i+1, state, strings.TrimSpace(stageOut))
			if bootcmd != "" {
				t.Log("[DIAG] edge-bootcmd.log present")
			} else {
				t.Log("[DIAG] edge-bootcmd.log missing")
			}
			if prelog != "" {
				t.Log("[DIAG] edge-userdata-pre.log present")
			} else {
				t.Log("[DIAG] edge-userdata-pre.log missing")
			}
			if dbglog != "" {
				t.Log("[DIAG] edge-debug.log present (runcmd echo executed)")
			} else {
				t.Log("[DIAG] edge-debug.log missing (runcmd likely not run yet)")
			}
			if psApt != "" {
				t.Log("[DIAG] processes:\n" + psApt)
			}
			if memFree != "" {
				t.Log("[DIAG] free -h:\n" + memFree)
			}
			if space != "" {
				t.Log("[DIAG] df -h /:\n" + space)
			}
			if errTail != "" {
				t.Log("[DIAG] recent cloud-init errors:\n" + errTail)
			}
		}

		t.Logf("Still waiting for cloud-init... (%d/%d)", i+1, maxWait/int(pollInterval.Seconds()))
		time.Sleep(pollInterval)
	}
	if !found {
		// Final diagnostics before failing
		t.Log("\033[1;33m[WARN]\033[0m Cloud-init not finished in time; collecting comprehensive logs...")
		out1, _ := ssh.CheckSshCommandE(t, host, "sudo tail -n 200 /var/log/cloud-init-output.log || true")
		out2, _ := ssh.CheckSshCommandE(t, host, "sudo tail -n 200 /var/log/cloud-init.log || true")
		out3, _ := ssh.CheckSshCommandE(t, host, "test -f /opt/startup.sh && echo exists || echo missing")
		out4, _ := ssh.CheckSshCommandE(t, host, "sudo bash -n /opt/startup.sh >/dev/null 2>&1 && echo syntax-ok || echo syntax-error")
		out5, _ := ssh.CheckSshCommandE(t, host, "cloud-init status --long 2>/dev/null || true")
		bootcmd, _ := ssh.CheckSshCommandE(t, host, "sudo cat /var/log/edge-bootcmd.log 2>/dev/null || true")
		prelog, _ := ssh.CheckSshCommandE(t, host, "sudo cat /var/log/edge-userdata-pre.log 2>/dev/null || true")
		dbglog, _ := ssh.CheckSshCommandE(t, host, "sudo cat /var/log/edge-debug.log 2>/dev/null || true")
		progress, _ := ssh.CheckSshCommandE(t, host, "sudo tail -n 120 /var/log/edge-progress.log 2>/dev/null || true")
		psFull, _ := ssh.CheckSshCommandE(t, host, "ps -eo pid,cmd | grep -E 'cloud-init|apt|dpkg' | grep -v grep || true")
		svc1, _ := ssh.CheckSshCommandE(t, host, "sudo systemctl status caddy --no-pager -l 2>/dev/null | tail -n 80 || true")
		reglog, _ := ssh.CheckSshCommandE(t, host, "sudo docker logs --tail 120 registry 2>/dev/null || true")
		disk, _ := ssh.CheckSshCommandE(t, host, "df -h || true")
		mem, _ := ssh.CheckSshCommandE(t, host, "free -h || true")
		t.Logf("/opt/startup.sh: %s, syntax: %s", strings.TrimSpace(out3), strings.TrimSpace(out4))
		t.Log("--- cloud-init-output.log (tail) ---\n" + out1)
		t.Log("--- cloud-init.log (tail) ---\n" + out2)
		t.Log("--- cloud-init status --long ---\n" + out5)
		t.Log("--- edge-bootcmd.log ---\n" + bootcmd)
		t.Log("--- edge-userdata-pre.log ---\n" + prelog)
		t.Log("--- edge-debug.log ---\n" + dbglog)
		t.Log("--- edge-progress.log ---\n" + progress)
		t.Log("--- processes (cloud-init/apt/dpkg) ---\n" + psFull)
		t.Log("--- systemctl status caddy (tail) ---\n" + svc1)
		t.Log("--- docker logs registry (tail) ---\n" + reglog)
		t.Log("--- df -h ---\n" + disk)
		t.Log("--- free -h ---\n" + mem)
		t.Log("\033[1;31m❌ [FAIL]\033[0m Cloud-init did not finish in time")
		f := fmt.Sprintf("Cloud-init did not finish within %d seconds", maxWait)
		t.Fatalf("%s", f)
	}

	t.Log("\033[1;34m[INFO]\033[0m Checking Docker installation (with retries)...")
	var dockerVersionOut string
	var dockerErr error
	for i := 0; i < 30; i++ { // ~5 minutes
		dockerVersionOut, dockerErr = ssh.CheckSshCommandE(t, host, "docker --version")
		if dockerErr == nil {
			break
		}
		time.Sleep(10 * time.Second)
	}
	if dockerErr != nil {
		t.Logf("\033[1;31m❌ [FAIL]\033[0m Docker not available after retries: %v", dockerErr)
		// Diagnostics
		out1, _ := ssh.CheckSshCommandE(t, host, "which docker || true")
		out2, _ := ssh.CheckSshCommandE(t, host, "dpkg -l | grep -i docker || true")
		out3, _ := ssh.CheckSshCommandE(t, host, "grep -E 'docker|caddy' -n /var/log/edge-init.log 2>/dev/null | tail -n 120 || true")
		out4, _ := ssh.CheckSshCommandE(t, host, "sudo systemctl status docker --no-pager -l 2>/dev/null | tail -n 120 || true")
		out5, _ := ssh.CheckSshCommandE(t, host, "sudo journalctl -u docker --no-pager -n 120 2>/dev/null || true")
		out6, _ := ssh.CheckSshCommandE(t, host, "tail -n 120 /var/log/cloud-init-output.log 2>/dev/null || true")
		out7, _ := ssh.CheckSshCommandE(t, host, "tail -n 120 /var/log/cloud-init.log 2>/dev/null || true")
		t.Log("--- which docker ---\n" + out1)
		t.Log("--- dpkg -l | grep docker ---\n" + out2)
		t.Log("--- edge-init.log (tail) ---\n" + out3)
		t.Log("--- systemctl status docker ---\n" + out4)
		t.Log("--- journalctl -u docker (tail) ---\n" + out5)
		t.Log("--- cloud-init-output.log (tail) ---\n" + out6)
		t.Log("--- cloud-init.log (tail) ---\n" + out7)
	}
	require.NoError(t, dockerErr, "Docker should be installed and available in PATH")
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

	// Ensure the caddy service is up before attempting ACME probing; sometimes validation completes
	// while the systemd unit is still (re)starting with the final Caddyfile.
	t.Log("\033[1;34m[INFO]\033[0m Waiting for caddy service to become active (up to 90s)...")
	for i := 0; i < 18; i++ { // 18 *5s = 90s
		statusOut, _ := ssh.CheckSshCommandE(t, host, "sudo systemctl is-active caddy || true")
		if strings.TrimSpace(statusOut) == "active" {
			if i > 0 {
				to := (i + 1) * 5
				t.Logf("[INFO] Caddy active after %ds", to)
			}
			break
		}
		if i == 17 {
			// Collect diagnostics but don't fail yet – subsequent steps will anyway.
			journal, _ := ssh.CheckSshCommandE(t, host, "sudo journalctl -u caddy -n 80 --no-pager 2>/dev/null || true")
			statusLong, _ := ssh.CheckSshCommandE(t, host, "sudo systemctl status caddy --no-pager -l 2>/dev/null | tail -n 80 || true")
			t.Log("[WARN] Caddy did not report active within 90s; continuing but ACME tests may fail.")
			t.Log("--- caddy status (tail) ---\n" + statusLong)
			t.Log("--- caddy journal (tail) ---\n" + journal)
		} else {
			time.Sleep(5 * time.Second)
		}
	}

	// Determine whether external registry host is using ACME (public cert) or internal CA
	// We'll extract the external host block from the Caddyfile and check for "tls internal" or a /ca.crt handler.
	findCaddyBlock := func(content, host string) (string, bool) {
		idx := strings.Index(content, host)
		if idx < 0 {
			return "", false
		}
		// find the first '{' after the host occurrence
		braceOpen := strings.Index(content[idx:], "{")
		if braceOpen < 0 {
			return "", false
		}
		start := idx + braceOpen
		depth := 0
		end := -1
		for i := start; i < len(content); i++ {
			if content[i] == '{' {
				depth++
			} else if content[i] == '}' {
				depth--
				if depth == 0 {
					end = i
					break
				}
			}
		}
		if end == -1 || end <= start+1 {
			return "", false
		}
		return content[start+1 : end], true
	}
	extBlock, ok := findCaddyBlock(caddyfileOut, registryExternalHost)
	// If we can't confidently detect, assume non-ACME (internal) to keep strict checks
	extUsesACME := false
	if ok {
		// ACME assumed if no explicit "tls internal" is present and no /ca.crt handler
		hasInternalTLS := strings.Contains(extBlock, "tls internal")
		hasCACrtHandler := strings.Contains(extBlock, "handle /ca.crt")
		extUsesACME = !(hasInternalTLS || hasCACrtHandler)
	}
	if extUsesACME {
		t.Log("\033[1;34m[INFO]\033[0m Detected ACME mode for external registry domain (public TLS)")
		// Improved wait loop: require an 'issuer=' line from openssl and that it is NOT the local authority.
		maxAttempts := 60 // up to 5 minutes (60 *5s)
		for i := 0; i < maxAttempts; i++ {
			// Use -showcerts and capture issuer + subject for clarity; keep stderr for diagnostics once every few attempts.
			issuerCmd := fmt.Sprintf("echo | openssl s_client -servername %s -connect 127.0.0.1:443 -showcerts 2>/dev/null | openssl x509 -noout -issuer -subject || true", registryExternalHost)
			issuerRaw, _ := ssh.CheckSshCommandE(t, host, issuerCmd)
			issuerRaw = strings.TrimSpace(issuerRaw)
			lines := strings.Split(issuerRaw, "\n")
			issuerLine := ""
			for _, ln := range lines {
				if strings.HasPrefix(strings.ToLower(strings.TrimSpace(ln)), "issuer=") {
					issuerLine = strings.TrimSpace(ln)
					break
				}
			}
			if issuerLine != "" && !strings.Contains(strings.ToLower(issuerLine), "caddy local authority") {
				t.Logf("\033[1;32m✅ [SUCCESS]\033[0m ACME certificate issuer detected: %s", issuerLine)
				break
			}
			if i == maxAttempts-1 {
				// Capture detailed diagnostics before failing
				fullDump, _ := ssh.CheckSshCommandE(t, host, fmt.Sprintf("echo | openssl s_client -servername %s -connect 127.0.0.1:443 2>&1 | head -n 120 || true", registryExternalHost))
				caddyStatus, _ := ssh.CheckSshCommandE(t, host, "sudo systemctl status caddy --no-pager -l 2>/dev/null | tail -n 80 || true")
				caddyLog, _ := ssh.CheckSshCommandE(t, host, "sudo journalctl -u caddy -n 80 --no-pager 2>/dev/null || true")
				t.Log("[DIAG] Final openssl s_client snippet (first 120 lines):\n" + fullDump)
				t.Log("[DIAG] caddy status (tail):\n" + caddyStatus)
				t.Log("[DIAG] caddy journal (tail):\n" + caddyLog)
				t.Fatalf("ACME certificate not observed after %d attempts (~%ds). Last issuer output: %s", maxAttempts, maxAttempts*5, issuerRaw)
			}
			if (i+1)%6 == 0 { // every ~30s show a progress line incl raw content trimmed
				preview := issuerRaw
				if len(preview) > 160 {
					preview = preview[:160] + "..."
				}
				t.Logf("[INFO] ACME wait attempt %d/%d issuerLine='%s' raw='%s'", i+1, maxAttempts, issuerLine, preview)
			}
			time.Sleep(5 * time.Second)
		}
	} else {
		t.Log("\033[1;34m[INFO]\033[0m External registry domain using internal CA")
	}

	t.Log("\033[1;34m[INFO]\033[0m Checking htpasswd file for registry user...")
	htpasswdCmd := "sudo cat /opt/registry/auth/htpasswd"
	// We'll assert against the actual username extracted below once available

	// --- Registry HTTP Auth Validation via Caddy (curl) ---
	t.Log("\033[1;34m[INFO]\033[0m Testing registry HTTP endpoints without auth (should be 401) for both domains (with retries for TLS readiness)...")
	for _, h := range []string{registryExternalHost, registryInternalHost} {
		attempts := 24 // up to 2 minutes
		var headersNoAuth string
		var cmdErr error
		for i := 0; i < attempts; i++ {
			curlNoAuthCmd := fmt.Sprintf("curl -s -k -D - -o /dev/null --connect-timeout 5 --resolve '%s:443:127.0.0.1' https://%s/v2/ || echo '__EXIT:$?'", h, h)
			headersNoAuth, cmdErr = ssh.CheckSshCommandE(t, host, curlNoAuthCmd)
			// Treat exit markers or empty output as transient if we haven't seen HTTP 401 yet
			if cmdErr == nil && strings.Contains(headersNoAuth, " 401") {
				break
			}
			if i == attempts-1 {
				// diagnostics
				opensslDump, _ := ssh.CheckSshCommandE(t, host, fmt.Sprintf("echo | openssl s_client -servername %s -connect 127.0.0.1:443 2>&1 | head -n 80 || true", h))
				caddyLog, _ := ssh.CheckSshCommandE(t, host, "sudo journalctl -u caddy -n 60 --no-pager 2>/dev/null || true")
				t.Log("--- openssl s_client (tail) ---\n" + opensslDump)
				t.Log("--- caddy journal (tail) ---\n" + caddyLog)
				require.NoError(t, cmdErr, fmt.Sprintf("curl no-auth failed for %s after retries", h))
				assert.Contains(t, headersNoAuth, " 401", "Unauthenticated request should return 401 for "+h)
			}
			time.Sleep(5 * time.Second)
		}
		if !strings.Contains(headersNoAuth, " 401") {
			t.Fatalf("Did not observe 401 from %s /v2/ after retries. Last output: %s", h, headersNoAuth)
		}
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
	// Verify Docker trust store setup according to mode:
	// - Internal domain: must always have internal CA
	// - External domain: CA expected only when NOT using ACME
	t.Log("\033[1;34m[INFO]\033[0m Verifying Docker trust store according to ACME/internal mode...")
	checkCA := func(h string) (bool, string, string) {
		caCheckCmd := fmt.Sprintf("test -f /etc/docker/certs.d/%s/ca.crt && echo present || echo missing", h)
		caStatus, _ := ssh.CheckSshCommandE(t, host, caCheckCmd)
		caCheckCmd443 := fmt.Sprintf("test -f /etc/docker/certs.d/%s:443/ca.crt && echo present || echo missing", h)
		caStatus443, _ := ssh.CheckSshCommandE(t, host, caCheckCmd443)
		has := strings.TrimSpace(caStatus) == "present" || strings.TrimSpace(caStatus443) == "present"
		return has, strings.TrimSpace(caStatus), strings.TrimSpace(caStatus443)
	}
	// Internal must have CA
	if has, s1, s2 := checkCA(registryInternalHost); !has {
		t.Logf("\033[1;31m❌ [FAIL]\033[0m Docker trust store missing CA for internal host %s (host: %s, host:443: %s)", registryInternalHost, s1, s2)
		require.Fail(t, "Missing Docker CA for internal registry host")
	} else {
		t.Logf("\033[1;32m✅ [SUCCESS]\033[0m Docker trust store has CA for internal host %s", registryInternalHost)
	}
	// External: expect CA only if not ACME
	if extUsesACME {
		if has, s1, s2 := checkCA(registryExternalHost); has {
			t.Logf("\033[1;33m[WARN]\033[0m External host %s has a CA file even in ACME mode (host: %s, :443: %s) — ok but unexpected", registryExternalHost, s1, s2)
		} else {
			t.Logf("\033[1;32m✅ [SUCCESS]\033[0m No Docker CA for external host %s (expected in ACME mode)", registryExternalHost)
		}
	} else {
		if has, s1, s2 := checkCA(registryExternalHost); !has {
			require.Failf(t, "Missing Docker CA for external host", "host: %s, :443: %s", s1, s2)
		} else {
			t.Logf("\033[1;32m✅ [SUCCESS]\033[0m Docker trust store has CA for external host %s (internal CA mode)", registryExternalHost)
		}
	}

	// For the purposes of this test, pin the registry hostnames to loopback on the edge host
	// so we don't depend on public DNS propagation. This does NOT change module behavior in real envs.
	t.Log("\033[1;34m[INFO]\033[0m Pinning registry hostnames to 127.0.0.1 in /etc/hosts for this test run...")
	for _, h := range []string{registryExternalHost, registryInternalHost} {
		addHostCmd := fmt.Sprintf("sudo bash -lc 'grep -q "+
			"\"^[[:space:]]*127\\.0\\.0\\.1[[:space:]]+%s(\\s|$)\" /etc/hosts || echo \"127.0.0.1 %s\" >> /etc/hosts'", h, h)
		_, err := ssh.CheckSshCommandE(t, host, addHostCmd)
		require.NoError(t, err, "Failed to add %s to /etc/hosts", h)
	}

	// Login to internal host for stability; external may depend on ACME issuance timing
	t.Log("\033[1;34m[INFO]\033[0m Docker login to internal registry via Caddy...")
	loginCmd := fmt.Sprintf("echo %s | docker login %s -u %s --password-stdin", shSingleQuote(regPass), registryInternalHost, shSingleQuote(regUser))
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
	// Use internal host for push/pull smoke test
	imageName := fmt.Sprintf("%s/test/%s:tt", registryInternalHost, baseName)
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

	// Optional: pull from Docker Hub and push into registry (on EDGE host) if enabled
	if dockerHubEnabled && !extClientEnabled {
		t.Log("\033[1;34m[INFO]\033[0m [DockerHub->Registry] Pulling busybox:latest from Docker Hub on edge host...")
		_, err := ssh.CheckSshCommandE(t, host, "docker pull busybox:latest")
		require.NoError(t, err, "docker pull busybox:latest should succeed from Docker Hub")
		hubImg := "busybox:latest"
		dest := fmt.Sprintf("%s/test/busybox:hub", registryExternalHost)
		t.Log("\033[1;34m[INFO]\033[0m Tagging and pushing image from Docker Hub into registry (edge host)...")
		_, err = ssh.CheckSshCommandE(t, host, fmt.Sprintf("docker tag %s %s && docker push %s", hubImg, dest, dest))
		require.NoError(t, err, "push of DockerHub image into registry should succeed")
		_, _ = ssh.CheckSshCommandE(t, host, fmt.Sprintf("docker rmi -f %s || true", dest))
		out, err := ssh.CheckSshCommandE(t, host, fmt.Sprintf("docker pull %s", dest))
		require.NoError(t, err)
		if !(strings.Contains(out, "Downloaded newer image") || strings.Contains(out, "Image is up to date") || strings.Contains(out, "Status: Downloaded")) {
			require.Fail(t, "DockerHub->Registry pull-back did not report success")
		}
		t.Log("\033[1;32m✅ [SUCCESS]\033[0m [DockerHub->Registry] Image flowed through via edge host")
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

	// ===============================
	// Optional: External client flow
	// ===============================
	if extClientEnabled {
		t.Log("\033[1;34m[INFO]\033[0m [EXT] Provisioning external client fixture for outside-VPC testing...")
		region := os.Getenv("AWS_REGION")
		if region == "" {
			region = "eu-central-1"
		}
		extTf := &terraform.Options{
			TerraformDir: "fixtures/external_client",
			NoColor:      true,
			Vars: map[string]interface{}{
				"region": region,
			},
		}
		defer terraform.Destroy(t, extTf)
		terraform.InitAndApply(t, extTf)
		extIP := terraform.Output(t, extTf, "public_ip")
		extKeyPath := terraform.Output(t, extTf, "private_key_path")
		keyBytes, err := os.ReadFile(extKeyPath)
		require.NoError(t, err)
		client := ssh.Host{Hostname: extIP, SshUserName: "ubuntu", SshKeyPair: &ssh.KeyPair{PrivateKey: string(keyBytes)}}

		// Wait for SSH on client
		for i := 0; i < 24; i++ {
			if err := ssh.CheckSshConnectionE(t, client); err == nil {
				break
			}
			time.Sleep(5 * time.Second)
			if i == 23 {
				require.Fail(t, "External client SSH not available in time")
			}
		}

		// Prepare DNS pin; then either install CA (internal mode) or skip (ACME mode)
		t.Log("\033[1;34m[INFO]\033[0m [EXT] Pinning registry domain to Edge EIP...")
		_, _ = ssh.CheckSshCommandE(t, client, fmt.Sprintf("echo '%s %s' | sudo tee -a /etc/hosts >/dev/null", publicIP, registryExternalHost))
		if extUsesACME {
			t.Log("\033[1;34m[INFO]\033[0m [EXT] ACME mode detected — skipping CA fetch/install on external client")
		} else {
			t.Log("\033[1;34m[INFO]\033[0m [EXT] Installing Caddy internal CA on external client...")
			fetchCACmd := fmt.Sprintf("for i in $(seq 1 60); do curl -fsSk --resolve '%s:443:%s' https://%s/ca.crt -o /tmp/caddy-local.crt && break || sleep 2; done; test -s /tmp/caddy-local.crt", registryExternalHost, publicIP, registryExternalHost)
			_, err = ssh.CheckSshCommandE(t, client, fetchCACmd)
			require.NoError(t, err, "[EXT] Failed to fetch Caddy CA from edge host")
			installCACmd := fmt.Sprintf("sudo bash -lc 'install -d -m 0755 /etc/docker/certs.d/%[1]s /etc/docker/certs.d/%[1]s:443 && install -m 0644 /tmp/caddy-local.crt /etc/docker/certs.d/%[1]s/ca.crt && install -m 0644 /tmp/caddy-local.crt /etc/docker/certs.d/%[1]s:443/ca.crt && install -m 0644 -D /tmp/caddy-local.crt /usr/local/share/ca-certificates/caddy-local.crt && update-ca-certificates || true && systemctl restart docker || true'", registryExternalHost)
			_, err = ssh.CheckSshCommandE(t, client, installCACmd)
			require.NoError(t, err, "[EXT] Failed to install CA on external client")
		}

		// Login (no CA needed in ACME mode)
		loginClientCmd := fmt.Sprintf("echo %s | docker login %s -u %s --password-stdin", shSingleQuote(regPass), registryExternalHost, shSingleQuote(regUser))
		loginClientOut, err := ssh.CheckSshCommandE(t, client, loginClientCmd)
		require.NoError(t, err, "[EXT] docker login should succeed")
		assert.Contains(t, loginClientOut, "Login Succeeded")

		// If requested, prove Docker Hub -> our registry flow entirely from outside
		if dockerHubEnabled {
			t.Log("\033[1;34m[INFO]\033[0m [EXT][DockerHub->Registry] Pulling busybox:latest from Docker Hub on external client...")
			_, err := ssh.CheckSshCommandE(t, client, "docker pull busybox:latest")
			require.NoError(t, err, "[EXT] docker pull busybox:latest should succeed")
			dest := fmt.Sprintf("%s/test/busybox:hub", registryExternalHost)
			t.Log("\033[1;34m[INFO]\033[0m [EXT] Tagging and pushing to registry...")
			_, err = ssh.CheckSshCommandE(t, client, fmt.Sprintf("docker tag busybox:latest %s && docker push %s", dest, dest))
			require.NoError(t, err, "[EXT] push of DockerHub image into registry should succeed")
			_, _ = ssh.CheckSshCommandE(t, client, fmt.Sprintf("docker rmi -f %s || true", dest))
			out, err := ssh.CheckSshCommandE(t, client, fmt.Sprintf("docker pull %s", dest))
			require.NoError(t, err)
			if !(strings.Contains(out, "Downloaded newer image") || strings.Contains(out, "Image is up to date") || strings.Contains(out, "Status: Downloaded")) {
				require.Fail(t, "[EXT] DockerHub->Registry pull-back did not report success")
			}
			t.Log("\033[1;32m✅ [SUCCESS]\033[0m [EXT][DockerHub->Registry] Image flowed through from Docker Hub")
		}
	}
}
