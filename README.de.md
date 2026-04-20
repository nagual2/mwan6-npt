# mwan6-npt

**Deutsch** | [English](README.md) | [Русский](README.ru.md)

NPTv6-Unterstützung (Network Prefix Translation) für mehrere IPv6-WAN-Schnittstellen auf OpenWrt.

## Übersicht

mwan6-npt verwaltet automatisch IPv6-Präfix-Übersetzungsregeln für aktive Tunnel/Schnittstellen und ermöglicht nahtloses IPv6-Multi-Homing unter Beibehaltung des LAN-Präfixes bei der Kommunikation über verschiedene WAN-Präfixe.

## Funktionen

- **UCI-Konfiguration**: Standard-OpenWrt-Konfigurationsschnittstelle
- **Hotplug-Integration**: Automatische Regel-Neugenerierung bei Schnittstellen-Up/Down-Ereignissen
- **procd-Unterstützung**: Richtiges Init-Skript mit Service-Triggern
- **nftables/fw4-Kompatibilität**: Verwendet OpenWrt 22.03+ Firewall-System
- **Multi-WAN-Unterstützung**: Konfiguration mehrerer Schnittstellen mit verschiedenen Präfixen
- **Standard-Gateway**: Markierung einer Schnittstelle als Standard für Traffic-Priorisierung

## Installation

### Aus Quellen bauen

```bash
cd $TOPDIR/package
mkdir -p custom
cp -r /path/to/mwan6-npt ./custom/
make menuconfig  # Network -> mwan6-npt auswählen
make package/mwan6-npt/compile
```

### Manuelle Installation

Dateien auf den Router kopieren:

```bash
# Paketdateien kopieren
scp -r files/* root@openwrt:/

# Berechtigungen setzen
ssh root@openwrt '
  chmod +x /etc/init.d/mwan6-npt
  chmod +x /etc/hotplug.d/iface/25-mwan6-npt
  chmod +x /usr/sbin/mwan6-npt
  chmod +x /usr/share/mwan6-npt/functions.sh
'
```

Aktivieren und starten:

```bash
/etc/init.d/mwan6-npt enable
/etc/init.d/mwan6-npt start
```

## Konfiguration

Bearbeiten Sie `/etc/config/mwan6-npt`:

```uci
config globals 'globals'
	option enabled '1'
	option lan_prefix 'fd00:1111:2222:f000::/64'
	option auto_reload '1'

config interface 'tb6'
	option enabled '1'
	option wan_prefix 'fd00:aaaa:bbbb:14f::/64'
	option default '1'

config interface 'tb62'
	option enabled '1'
	option wan_prefix 'fd00:aaaa:bbbb:1b8::/64'
	option default '0'
```

### Optionen

**globals-Sektion:**
- `enabled`: Service aktivieren/deaktivieren (0/1)
- `lan_prefix`: Ihr LAN-IPv6-Präfix (/64)
- `auto_reload`: Firewall bei Änderungen automatisch neu laden (0/1)

**interface-Sektion:**
- `enabled`: Diese Schnittstelle aktivieren (0/1)
- `wan_prefix`: WAN-IPv6-Präfix für diese Schnittstelle (/64)
- `default`: Als Standardschnittstelle markieren (nur eine sollte `1` haben)

## Verwendung

### CLI-Befehle

```bash
# Regeln manuell aktualisieren
/usr/sbin/mwan6-npt update

# Status prüfen
/usr/sbin/mwan6-npt status

# Alle Regeln löschen
/usr/sbin/mwan6-npt flush

# Service steuern
/etc/init.d/mwan6-npt {start|stop|restart|reload|enable|disable}
```

### UCI-Befehle

```bash
# LAN-Präfix setzen (ULA-Beispiel zum Testen)
uci set mwan6-npt.globals.lan_prefix='fd00:1111:2222:f000::/64'

# Neue Schnittstelle hinzufügen
uci add mwan6-npt interface
uci set mwan6-npt.@interface[-1].name='tb64'
uci set mwan6-npt.@interface[-1].wan_prefix='fd00:eeee:ffff:1f5::/64'
uci set mwan6-npt.@interface[-1].enabled='1'
uci set mwan6-npt.@interface[-1].default='0'

# Standardschnittstelle wechseln
uci set mwan6-npt.tb6.default='0'
uci set mwan6-npt.tb64.default='1'

# Änderungen anwenden
uci commit mwan6-npt
/etc/init.d/mwan6-npt reload
```

## Überprüfung

Aktive Regeln prüfen:

```bash
# NPTv6-Regeln in nftables auflisten
nft list chain inet fw4 srcnat | grep -E 'snat prefix'
nft list chain inet fw4 dstnat | grep -E 'dnat prefix'

# Test von LAN-Gerät
ping6 fd00:aaaa:bbbb:14f::1
# Sollte über NPTv6-Übersetzung funktionieren
```

## Architektur

```
Schnittstelle UP/DOWN
       ↓
hotplug.d/iface/25-mwan6-npt
       ↓
/usr/sbin/mwan6-npt update
       ↓
/etc/config/mwan6-npt (UCI)
       ↓
generates → /usr/share/nftables.d/chain-post/{srcnat,dstnat}/99-mwan6-npt.nft
       ↓
fw4 reload → aktive nftables-Regeln
```

## Testen mit ULA

Zum Testen auf `openwrt-dev` verwenden Sie ULA-Präfixe (fd00::/8):

```bash
# LAN-Präfix (ULA)
fd00:1111:2222:f000::/64

# WAN-Präfixe (ULA)
fd00:aaaa:bbbb:14f::/64
fd00:aaaa:bbbb:1b8::/64
fd00:cccc:dddd:1f4::/64
```

ULA-Adressen erfordern keine echte IPv6-Konnektivität und sind sicher für Labortests.

## Anforderungen

- OpenWrt 22.03+ (fw4/nftables)
- Paket `nftables`
- Paket `ip-full`

## Lizenz

GPL-2.0

## Autor

OpenWrt Community
