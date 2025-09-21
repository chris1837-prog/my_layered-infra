# WireGuard Admin Onboarding

Edge wg0: 10.200.0.1/24  
App peer: 10.200.0.2/32  

## Add Admin Peer
sudo /etc/wireguard/scripts/wg-peer.sh add admin1 10.200.0.10  

## Remove Admin Peer
sudo /etc/wireguard/scripts/wg-peer.sh remove admin1 10.200.0.10  

## Security Notes
- Rotate keys periodically  
- Revoke peers with remove command  
- Logs: journalctl -u wg-quick@wg0

## Caddy HTTPS
- /health path available via https://<domain>/health
- Logs: /var/log/caddy/access.log
- HTTP→HTTPS redirect handled automatically
