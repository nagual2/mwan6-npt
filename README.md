# mwan6-npt

[English](README.md) | [Русский](README.ru.md) | [Deutsch](README.de.md)

NPTv6 (Network Prefix Translation) support for multiple IPv6 WAN interfaces on OpenWrt.

## Overview

mwan6-npt automatically manages IPv6 prefix translation rules for active tunnels/interfaces, enabling seamless IPv6 multi-homing while preserving the LAN prefix when communicating through different WAN prefixes.

## Features

- **UCI Configuration**: Standard OpenWrt configuration interface
- **Hotplug Integration**: Automatic rule regeneration on interface up/down events
- **procd Support**: Proper init script with service triggers
- **nftables/fw4 Compatible**: Uses OpenWrt 22.03+ firewall system
- **Multiple WAN Support**: Configure multiple interfaces with different prefixes
- **Prefix detection**: `detect-lan-prefix.sh` and `detect-wan-prefix.sh` helpers for LuCI/CLI
- **LAN-only first install**: Default UCI contains only `lan`; service disabled until configured

## Installation

### Install from release packages

Download from [Releases](https://github.com/nagual2/mwan6-npt/releases):

```bash
# OpenWrt 23.x (opkg)
wget https://github.com/nagual2/mwan6-npt/releases/download/v1.1.1/mwan6-npt_1.1.1-1_all.ipk -O /tmp/mwan6-npt.ipk
opkg install /tmp/mwan6-npt.ipk

# OpenWrt 25.12+ (apk)
wget https://github.com/nagual2/mwan6-npt/releases/download/v1.1.1/mwan6-npt-1.1.1-r1.apk -O /tmp/mwan6-npt.apk
apk add --allow-untrusted /tmp/mwan6-npt.apk
```

On **first install** the package creates only the `lan` section (NPT source), service **disabled** (`globals.enabled=0`). LAN prefix is auto-detected from `network` (single `ip6prefix` or delegation on `lan`). WAN tunnels are added via **luci-app-mwan6-npt** or manual UCI — WAN prefixes are **not** written to `network`, only used for NPT.

```bash
# Review configuration first
vi /etc/config/mwan6-npt

# Generate rules and reload firewall
/etc/init.d/mwan6-npt reload

# Optional: enable/start procd service after globals.enabled is set
/etc/init.d/mwan6-npt enable
/etc/init.d/mwan6-npt start
```

### Build IPK from Source

```bash
# Clone repository
git clone https://github.com/nagual2/mwan6-npt.git
cd mwan6-npt

# Build package (requires make and ar)
make -f Makefile.build ipk

# Copy to router
scp dist/mwan6-npt_*.ipk root@openwrt:/tmp/
```

### Build from OpenWrt SDK

```bash
cd $TOPDIR/package
mkdir -p custom
cp -r /path/to/mwan6-npt ./custom/
make menuconfig  # Select Network -> mwan6-npt
make package/mwan6-npt/compile
```

### Manual Installation

Copy files to your router:

```bash
# Copy package files
scp -r files/* root@openwrt:/

# Set permissions
ssh root@openwrt '
  chmod +x /etc/init.d/mwan6-npt
  chmod +x /etc/hotplug.d/iface/25-mwan6-npt
  chmod +x /usr/sbin/mwan6-npt
  chmod +x /usr/share/mwan6-npt/functions.sh
'
```

Enable and start:

```bash
/etc/init.d/mwan6-npt enable
/etc/init.d/mwan6-npt start
```

## Configuration

Edit `/etc/config/mwan6-npt`:

```uci
config globals 'globals'
	option enabled '0'

config interface 'lan'
	option enabled '1'
	option wan_prefix '2001:db8::/56'
	option default '1'

config interface 'tb62'
	option enabled '1'
	option wan_prefix '2001:db8:1::/56'
	option default '0'
```

The `lan` section is created on install; WAN sections (e.g. `tb62`) are added by the administrator via LuCI or UCI.

### Options

**globals section:**
- `enabled`: Enable the procd service start path (0/1)

**interface section:**
- `enabled`: Include this interface in NPT processing (0/1)
- `wan_prefix`: IPv6 prefix for this interface
- `default`: Mark the section that provides the source LAN prefix for NPTv6 (only one should have `1`)
  - The `default=1` section is not a default gateway selector
  - The `default=1` section provides the LAN/source prefix used for translation
  - All other enabled interfaces translate to/from this prefix

### Routed Prefix Scenario

If one WAN tunnel already carries the routed LAN prefix and LAN clients use that prefix directly via RA/SLAAC, do not translate through that tunnel.

Example:

```uci
config interface 'lan'
	option enabled '1'
	option wan_prefix '<routed-lan-prefix>'
	option default '1'

config interface 'tb64'
	option enabled '0'
	option wan_prefix '<tb64-wan-prefix>'
	option default '0'
```

In this setup:
- `lan.wan_prefix` holds the routed LAN prefix
- `tb64.enabled='0'` excludes `tb64` from translation because NPT is not needed for that path
- Other WAN/tunnel interfaces that need prefix translation remain `enabled='1'`

## Usage

### CLI Commands

```bash
# Update rules manually
/usr/sbin/mwan6-npt update

# Check status
/usr/sbin/mwan6-npt status

# Flush all rules
/usr/sbin/mwan6-npt flush

# Control service
/etc/init.d/mwan6-npt {start|stop|restart|reload|enable|disable}
```

### UCI Commands

```bash
# Add new WAN interface
uci add mwan6-npt interface
uci set mwan6-npt.@interface[-1].name='tb64'
uci set mwan6-npt.@interface[-1].wan_prefix='fd00:eeee:ffff:1f5::/64'
uci set mwan6-npt.@interface[-1].enabled='1'
uci set mwan6-npt.@interface[-1].default='0'

# Enable service logic
uci set mwan6-npt.globals=globals
uci set mwan6-npt.globals.enabled='1'

# Exclude a tunnel from translation when it already carries the routed LAN prefix
uci set mwan6-npt.tb64.enabled='0'

# Commit and reload
uci commit mwan6-npt
/etc/init.d/mwan6-npt reload
```

## Verification

Check active rules:

```bash
# List NPTv6 rules in nftables
nft list chain inet fw4 srcnat | grep -E 'snat prefix'
nft list chain inet fw4 dstnat | grep -E 'dnat prefix'

# Check generated files
cat /usr/share/nftables.d/chain-post/srcnat/99-mwan6-npt.nft
cat /usr/share/nftables.d/chain-post/dstnat/99-mwan6-npt.nft

# Test from LAN device
ping6 fd00:aaaa:bbbb:14f::1
# Should work through NPTv6 translation
```

## Architecture

```
Interface UP/DOWN
       ↓
hotplug.d/iface/25-mwan6-npt
       ↓
/usr/sbin/mwan6-npt update
       ↓
/etc/config/mwan6-npt (UCI)
       ↓
generates → /usr/share/nftables.d/chain-post/{srcnat,dstnat}/99-mwan6-npt.nft
       ↓
fw4 reload → nftables rules active
```

## Testing with ULA

For lab testing on a router, use ULA prefixes (fd00::/8):

```bash
# LAN prefix (ULA) - from the default/source LAN section
fd00:1111:2222:f000::/64

# WAN prefixes (ULA)
fd00:aaaa:bbbb:14f::/64
fd00:aaaa:bbbb:1b8::/64
fd00:cccc:dddd:1f4::/64
```

ULA addresses don't require real IPv6 connectivity and are safe for lab testing.

## Requirements

- OpenWrt 22.03+ (fw4/nftables)
- `nftables` package
- `ip-full` package

## Documentation

Trilingual README files are installed with the package under `/usr/share/doc/mwan6-npt/`:

| File | Language |
|------|----------|
| `README.en.md` | English |
| `README.ru.md` | Russian |
| `README.de.md` | German |

## License

Apache-2.0 (same license as [LuCI](https://github.com/openwrt/luci)). See `LICENSE` and `NOTICE` in the repository and in `/usr/share/doc/mwan6-npt/` on the router.

## Author

OpenWrt Community
