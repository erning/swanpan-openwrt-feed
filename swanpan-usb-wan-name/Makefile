include $(TOPDIR)/rules.mk

PKG_NAME:=swanpan-usb-wan-name
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=Proprietary
PKG_URL:=https://github.com/erning/swanpan-openwrt-feed

include $(INCLUDE_DIR)/package.mk

define Package/swanpan-usb-wan-name
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Swanpan
  TITLE:=Stable name for supported USB WAN devices
  DEPENDS:=+ip
  PKGARCH:=all
endef

define Package/swanpan-usb-wan-name/description
 Renames supported USB Ethernet WAN devices to cellular0 during net hotplug.
endef

define Build/Compile
endef

define Package/swanpan-usb-wan-name/install
	$(INSTALL_DIR) $(1)/etc/hotplug.d/net
	$(INSTALL_BIN) ./files/10-usb-wan-name \
		$(1)/etc/hotplug.d/net/10-usb-wan-name
endef

$(eval $(call BuildPackage,swanpan-usb-wan-name))
