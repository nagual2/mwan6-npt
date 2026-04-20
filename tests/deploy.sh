#!/bin/sh
# Deploy mwan6-npt to openwrt-dev
# Usage: SSH_KEY=~/.ssh/my_key ./deploy.sh [HOST]

set -e

PKG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOST="${1:-dev-openwrt}"
SSH_KEY="${SSH_KEY:-${HOME}/.ssh/id_ed25519}"

echo "================================"
echo "Deploy mwan6-npt to $HOST"
echo "================================"

# Check SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH key not found: $SSH_KEY"
    echo "Set key with: SSH_KEY=/path/to/key ./deploy.sh"
    echo "Or generate: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''"
    exit 1
fi

# Check host is reachable
if ! ping -c 1 -W 2 "$HOST" >/dev/null 2>&1; then
    echo "Error: Host $HOST not reachable"
    echo "Usage: $0 [hostname] or set host in /etc/hosts"
    exit 1
fi

echo ""
echo "Using SSH key: $SSH_KEY"
echo "Target host: $HOST"
echo ""
echo "Step 1: Copying package files..."

# Copy files using scp via WSL
wsl scp -i "$SSH_KEY" -r "$PKG_DIR/files/*" "root@$HOST:/"

echo ""
echo "Step 2: Setting permissions..."

wsl ssh -i "$SSH_KEY" "root@$HOST" '
    chmod +x /etc/init.d/mwan6-npt
    chmod +x /etc/hotplug.d/iface/25-mwan6-npt
    chmod +x /usr/sbin/mwan6-npt
    chmod +x /usr/share/mwan6-npt/functions.sh
    chmod +x /etc/uci-defaults/99-mwan6-npt
    echo "Permissions set"
'

echo ""
echo "Step 3: Enabling service..."

wsl ssh -i "$SSH_KEY" "root@$HOST" '
    /etc/init.d/mwan6-npt enable
    echo "Service enabled"
'

echo ""
echo "Step 4: Running initial configuration..."

wsl ssh -i "$SSH_KEY" "root@$HOST" '
    # Run uci-defaults
    /etc/uci-defaults/99-mwan6-npt
    
    # Check config
    echo ""
    echo "Current config:"
    uci show mwan6-npt
'

echo ""
echo "Step 5: Generating rules..."

wsl ssh -i "$SSH_KEY" "root@$HOST" '
    /usr/sbin/mwan6-npt update
'

echo ""
echo "Step 6: Verifying installation..."

wsl ssh -i "$SSH_KEY" "root@$HOST" '
    echo ""
    echo "=== Service status ==="
    /etc/init.d/mwan6-npt status 2>/dev/null || echo "Status check requires running daemon"
    
    echo ""
    echo "=== Generated rules ==="
    /usr/sbin/mwan6-npt status
    
    echo ""
    echo "=== nftables rules ==="
    nft list chain inet fw4 srcnat 2>/dev/null | grep -E "snat prefix" || echo "No SNAT rules"
    nft list chain inet fw4 dstnat 2>/dev/null | grep -E "dnat prefix" || echo "No DNAT rules"
'

echo ""
echo "================================"
echo "Deployment complete!"
echo "================================"
echo ""
echo "Test with:"
echo "  wsl ssh -i $SSH_KEY root@$HOST '/usr/sbin/mwan6-npt status'"
echo ""
