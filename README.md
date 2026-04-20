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
- **Default Gateway**: Mark one interface as LAN (default) for NPTv6 translation

## Installation

### Build from Source

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
config interface 'lan'
	option enabled '1'
	option wan_prefix 'fd00:1111:2222:f000::/64'
	option default '1'

config interface 'tb6'
	option enabled '1'
	option wan_prefix 'fd00:aaaa:bbbb:14f::/64'
	option default '0'

config interface 'tb62'
	option enabled '1'
	option wan_prefix 'fd00:aaaa:bbbb:1b8::/64'
	option default '0'
```

### Options

**interface section:**
- `enabled`: Enable this interface (0/1)
- `wan_prefix`: IPv6 prefix for this interface (/64)
- `default`: Mark as LAN/default interface (only one should have `1`)
  - The default interface provides the LAN prefix for NPTv6 translation
  - All other interfaces translate to/from this prefix

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

# Switch default (LAN) interface
uci set mwan6-npt.lan.default='0'
uci set mwan6-npt.tb6.default='1'

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

For testing on `openwrt-dev`, use ULA prefixes (fd00::/8):

```bash
# LAN prefix (ULA) - from default interface
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

## License

GPL-2.0

## Author

OpenWrt Community
