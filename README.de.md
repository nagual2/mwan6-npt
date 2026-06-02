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
- **LAN-Präfix-Quelle**: Eine Schnittstelle als Quelle des LAN-Präfixes für die NPTv6-Übersetzung markieren

## Installation

### Installation aus IPK (Empfohlen)

Laden Sie das neueste `.ipk`-Paket von [Releases](https://github.com/nagual2/mwan6-npt/releases) herunter und installieren Sie es:

```bash
# Auf den Router herunterladen
wget https://github.com/nagual2/mwan6-npt/releases/download/v1.1.1/mwan6-npt_1.1.1-1_all.ipk -O /tmp/mwan6-npt.ipk

# OpenWrt 23.x (opkg)
opkg install /tmp/mwan6-npt.ipk

# OpenWrt 25.12+ (apk)
wget https://github.com/nagual2/mwan6-npt/releases/download/v1.1.1/mwan6-npt-1.1.1-r1.apk -O /tmp/mwan6-npt.apk
apk add --allow-untrusted /tmp/mwan6-npt.apk
# oder: ./scripts/install-apk.sh 192.168.1.1
```

**apk-Pin:** `mwan6-npt><Q1hash…` in `/etc/apk/world` — siehe [luci-app-mwan3 — Pinning](https://github.com/nagual2/luci-app-mwan3#pinning-the-nagual2-fork-apk).

Prüfen Sie nach der Installation zuerst `/etc/config/mwan6-npt` und führen Sie dann ein `reload` des Dienstes aus:

```bash
# Konfiguration zuerst prüfen
vi /etc/config/mwan6-npt

# Regeln erzeugen und Firewall neu laden
/etc/init.d/mwan6-npt reload

# Optional: procd-Dienst aktivieren/starten, nachdem globals.enabled gesetzt wurde
/etc/init.d/mwan6-npt enable
/etc/init.d/mwan6-npt start
```

### IPK aus Quellen bauen

```bash
# Repository klonen
git clone https://github.com/nagual2/mwan6-npt.git
cd mwan6-npt

# Paket bauen (erfordert make und ar)
make -f Makefile.build ipk

# Auf den Router kopieren
scp dist/mwan6-npt_*.ipk root@openwrt:/tmp/
```

### Aus OpenWrt SDK bauen

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

### Optionen

**globals-Sektion:**
- `enabled`: Aktiviert den Startpfad des procd-Dienstes (0/1)

**interface-Sektion:**
- `enabled`: Nimmt diese Schnittstelle in die NPT-Verarbeitung auf (0/1)
- `wan_prefix`: IPv6-Präfix für diese Schnittstelle
- `default`: Markiert die Sektion, die das Quell-LAN-Präfix für NPTv6 bereitstellt (nur eine sollte `1` haben)
  - Die Sektion mit `default=1` wählt kein Default Gateway aus
  - Die Sektion mit `default=1` liefert das LAN-/Quellpräfix für die Übersetzung
  - Alle anderen Schnittstellen übersetzen zu/von diesem Präfix

### Szenario mit geroutetem Präfix

Wenn ein WAN-Tunnel das geroutete LAN-Präfix bereits trägt und LAN-Clients dieses Präfix direkt per RA/SLAAC verwenden, darf über diesen Tunnel keine Übersetzung erfolgen.

Beispiel:

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

In diesem Szenario:
- `lan.wan_prefix` enthält das geroutete LAN-Präfix
- `tb64.enabled='0'` schließt `tb64` von der Übersetzung aus, weil NPT für diesen Pfad nicht benötigt wird
- Andere WAN-/Tunnel-Schnittstellen, die Präfixübersetzung benötigen, bleiben mit `enabled='1'` aktiv

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
# Neue WAN-Schnittstelle hinzufügen
uci add mwan6-npt interface
uci set mwan6-npt.@interface[-1].name='tb64'
uci set mwan6-npt.@interface[-1].wan_prefix='fd00:eeee:ffff:1f5::/64'
uci set mwan6-npt.@interface[-1].enabled='1'
uci set mwan6-npt.@interface[-1].default='0'

# Dienstlogik aktivieren
uci set mwan6-npt.globals=globals
uci set mwan6-npt.globals.enabled='1'

# Tunnel von der Übersetzung ausschließen, wenn er bereits das geroutete LAN-Präfix trägt
uci set mwan6-npt.tb64.enabled='0'

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

# Generierte Dateien prüfen
cat /usr/share/nftables.d/chain-post/srcnat/99-mwan6-npt.nft
cat /usr/share/nftables.d/chain-post/dstnat/99-mwan6-npt.nft

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

Zum Testen auf einem Labor-Router verwenden Sie ULA-Präfixe (fd00::/8):

```bash
# LAN-Präfix (ULA) — aus der Default-/Source-LAN-Sektion
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

## Verwandte Pakete

| Paket | Repository |
|-------|------------|
| mwan3 (Fork) | [nagual2/mwan3](https://github.com/nagual2/mwan3) |
| luci-app-mwan3 | [nagual2/luci-app-mwan3](https://github.com/nagual2/luci-app-mwan3) |
| luci mwan6-npt | [nagual2/mwan6-npt-luci](https://github.com/nagual2/mwan6-npt-luci) |

**Gesamter Stack:** [docs/INSTALL-stack.de.md](docs/INSTALL-stack.de.md) (auf dem Router: `/usr/share/doc/mwan6-npt/INSTALL-stack.de.md`). [English](docs/INSTALL-stack.en.md) · [Русский](docs/INSTALL-stack.ru.md).

## Dokumentation

Dreisprachige README- und Stack-Anleitungen unter `/usr/share/doc/mwan6-npt/` (`README.en.md`, `README.ru.md`, `README.de.md`, `INSTALL-stack.en.md`, `INSTALL-stack.ru.md`, `INSTALL-stack.de.md`).

## Lizenz

Apache-2.0 (wie [LuCI](https://github.com/openwrt/luci)). Siehe `LICENSE` und `NOTICE` im Repository und auf dem Router.

## Autor

OpenWrt Community
