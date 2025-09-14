#!/bin/bash
# wg-peer.sh - Add/Remove WireGuard admin peers for Edge

EDGE_PUBLIC_IP="18.159.213.209"    # Replace with terraform output edge_public_ip
WG_SERVER_PORT=51820               # WireGuard server port
WG_NETWORK="10.200.0.0/24"        # WireGuard network

CONFIG_DIR="$HOME/wg-admins"
mkdir -p "$CONFIG_DIR"

function add_peer() {
  NAME=$1
  PEER_IP=$2
  FILE="$CONFIG_DIR/${NAME}.conf"

  if [ -f "$FILE" ]; then
    echo "Peer $NAME already exists at $FILE"
    return
  fi

  # Generate private key
  PRIVATE_KEY=$(wg genkey)
  PUBLIC_KEY=$(echo "$PRIVATE_KEY" | wg pubkey)

  cat > "$FILE" <<EOL
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $PEER_IP/32
DNS = 1.1.1.1

[Peer]
PublicKey = REPLACE_WITH_EDGE_PUBLIC_KEY
Endpoint = $EDGE_PUBLIC_IP:$WG_SERVER_PORT
AllowedIPs = $WG_NETWORK
PersistentKeepalive = 25
EOL

  echo "Peer config created: $FILE"
}

function remove_peer() {
  NAME=$1
  FILE="$CONFIG_DIR/${NAME}.conf"

  if [ -f "$FILE" ]; then
    rm "$FILE"
    echo "Peer $NAME removed."
  else
    echo "Peer $NAME does not exist."
  fi
}

function usage() {
  echo "Usage: $0 add|remove <peer_name> <peer_ip>"
  echo "Example: $0 add admin1 10.200.0.10"
}

# Main
if [ "$1" == "add" ]; then
  add_peer $2 $3
elif [ "$1" == "remove" ]; then
  remove_peer $2
else
  usage
fi
