#!/bin/bash

# PgBouncer connectivity smoke test
set -e

LOCAL_IP="127.0.0.1"
PGBOUNCER_PORT="6432"

# Get WireGuard IP (adjust interface name if needed)
WG_IP=$(ip addr show wg0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1) || WG_IP=""

echo "Testing PgBouncer connectivity..."

# Test 1: Localhost connection should succeed
echo "Testing localhost connection..."
if nc -zv ${LOCAL_IP} ${PGBOUNCER_PORT} 2>&1 | grep -q "succeeded"; then
    echo "✓ SUCCESS: PgBouncer accessible via 127.0.0.1:6432"
else
    echo "✗ FAIL: PgBouncer not accessible via 127.0.0.1:6432"
    exit 1
fi

# Test 2: WireGuard IP connection should fail (if WG interface exists)
if [ -n "${WG_IP}" ]; then
    echo "Testing WireGuard IP connection (should fail)..."
    if nc -zv ${WG_IP} ${PGBOUNCER_PORT} 2>&1 | grep -q "succeeded"; then
        echo "✗ FAIL: PgBouncer accessible via WG IP ${WG_IP}:6432 - security violation!"
        exit 1
    else
        echo "✓ SUCCESS: PgBouncer correctly blocked on WG IP ${WG_IP}:6432"
    fi
fi

# Test 3: External IP connection should fail
echo "Testing external IP connection (should fail)..."
if nc -zv $(hostname -I | awk '{print $1}') ${PGBOUNCER_PORT} 2>&1 | grep -q "succeeded"; then
    echo "✗ FAIL: PgBouncer accessible via external IP - security violation!"
    exit 1
else
    echo "✓ SUCCESS: PgBouncer correctly blocked on external IP"
fi

echo "All connectivity tests passed! PgBouncer is properly configured for loopback-only access."
