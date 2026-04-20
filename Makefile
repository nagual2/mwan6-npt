#
# Copyright (C) 2025 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=mwan6-npt
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_MAINTAINER:=OpenWrt Community
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/mwan6-npt
  SECTION:=net
  CATEGORY:=Network
  TITLE:=NPTv6 for Multi-WAN
  DEPENDS:=+nftables +ip-full
  PKGARCH:=all
endef

define Package/mwan6-npt/description
  mwan6-npt provides NPTv6 (Network Prefix Translation) support for multiple
  IPv6 WAN interfaces. It automatically manages prefix translation rules for
  active tunnels/interfaces, allowing seamless IPv6 multi-homing with prefix
  preservation from LAN to WAN.
endef

define Build/Compile
endef

define Package/mwan6-npt/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/etc/config/mwan6-npt $(1)/etc/config/
	
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/mwan6-npt $(1)/etc/init.d/
	
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_BIN) ./files/etc/hotplug.d/iface/25-mwan6-npt $(1)/etc/hotplug.d/iface/
	
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-mwan6-npt $(1)/etc/uci-defaults/
	
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/usr/sbin/mwan6-npt $(1)/usr/sbin/
	
	$(INSTALL_DIR) $(1)/usr/share/mwan6-npt
	$(INSTALL_DATA) ./files/usr/share/mwan6-npt/functions.sh $(1)/usr/share/mwan6-npt/
endef

$(eval $(call BuildPackage,mwan6-npt))
