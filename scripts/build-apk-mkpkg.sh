#!/usr/bin/env bash
# Build mwan6-npt .apk for OpenWrt 25.12+ using apk mkpkg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT/dist}"
SDK_DIR="${SDK_DIR:-$ROOT/build/sdk}"
APK_TOOL="${APK_TOOL:-$SDK_DIR/staging_dir/host/bin/apk}"

PROJECT_VERSION="${PROJECT_VERSION:-$(git -C "$ROOT" describe --tags --match 'v*' 2>/dev/null | sed 's/^v//')}"
PROJECT_VERSION="${PROJECT_VERSION:-1.0.1}"
PKG_RELEASE="${PKG_RELEASE:-2}"
PKG_VERSION="${PROJECT_VERSION}-r${PKG_RELEASE}"

log() { printf '[build-apk-mkpkg] %s\n' "$*"; }

ensure_apk_tool() {
	if [ -x "$APK_TOOL" ]; then
		return 0
	fi

	local archive url
	url="${SDK_URL:-https://downloads.openwrt.org/releases/25.12.0/targets/x86/64/openwrt-sdk-25.12.0-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst}"
	archive="$ROOT/build/$(basename "$url")"

	log "Extracting apk host tool from OpenWrt SDK..."
	mkdir -p "$ROOT/build"
	[ -f "$archive" ] || wget -O "$archive" "$url"
	rm -rf "$SDK_DIR"
	mkdir -p "$SDK_DIR"
	tar --zstd -xf "$archive" -C "$SDK_DIR" --strip-components=1
	APK_TOOL="$SDK_DIR/staging_dir/host/bin/apk"
	[ -x "$APK_TOOL" ] || {
		echo "apk tool not found after SDK extract: $APK_TOOL" >&2
		exit 1
	}
}

ensure_apk_tool

STAGE="$(mktemp -d)"
POSTINST="$(mktemp)"
trap 'rm -rf "$STAGE" "$POSTINST"' EXIT

install -d \
	"$STAGE/etc/config" \
	"$STAGE/etc/init.d" \
	"$STAGE/etc/hotplug.d/iface" \
	"$STAGE/etc/uci-defaults" \
	"$STAGE/usr/sbin" \
	"$STAGE/usr/share/mwan6-npt"

install -m 0644 "$ROOT/files/etc/config/mwan6-npt" "$STAGE/etc/config/"
install -m 0755 "$ROOT/files/etc/init.d/mwan6-npt" "$STAGE/etc/init.d/"
install -m 0755 "$ROOT/files/etc/hotplug.d/iface/25-mwan6-npt" "$STAGE/etc/hotplug.d/iface/"
install -m 0755 "$ROOT/files/etc/uci-defaults/99-mwan6-npt" "$STAGE/etc/uci-defaults/"
install -m 0755 "$ROOT/files/usr/sbin/mwan6-npt" "$STAGE/usr/sbin/"
install -m 0644 "$ROOT/files/usr/share/mwan6-npt/functions.sh" "$STAGE/usr/share/mwan6-npt/"
install -m 0755 "$ROOT/files/usr/share/mwan6-npt/detect-lan-prefix.sh" "$STAGE/usr/share/mwan6-npt/"
install -m 0755 "$ROOT/files/usr/share/mwan6-npt/detect-wan-prefix.sh" "$STAGE/usr/share/mwan6-npt/"

cat >"$POSTINST" <<'EOF'
#!/bin/sh
[ -n "${IPKG_INSTROOT}" ] && exit 0
[ -x /etc/uci-defaults/99-mwan6-npt ] && /etc/uci-defaults/99-mwan6-npt || true
exit 0
EOF
chmod 0755 "$POSTINST"

mkdir -p "$OUTPUT_DIR"
OUT_APK="$OUTPUT_DIR/mwan6-npt-${PKG_VERSION}.apk"

log "Creating $OUT_APK"
"$APK_TOOL" mkpkg \
	--compat 3.0.0_pre1 \
	--files "$STAGE" \
	--info "name:mwan6-npt" \
	--info "version:${PKG_VERSION}" \
	--info "arch:noarch" \
	--info "license:GPL-2.0" \
	--info "maintainer:OpenWrt Community" \
	--info "depends:nftables-json ip" \
	--info "description:NPTv6 Multi-WAN for OpenWrt" \
	--script "post-install:$POSTINST" \
	--output "$OUT_APK"

log "Built: $OUT_APK ($(wc -c <"$OUT_APK") bytes)"
