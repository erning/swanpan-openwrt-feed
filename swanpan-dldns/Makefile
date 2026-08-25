include $(TOPDIR)/rules.mk

PKG_NAME:=swanpan-dldns
PKG_VERSION:=0.4.0
PKG_RELEASE:=1

DLDNS_SOURCE_VERSION:=6b1b203e0d1c3fc0f878e46dec337844cf619de7
PKG_SOURCE:=dldns-$(DLDNS_SOURCE_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/erning/dldns/tar.gz/$(DLDNS_SOURCE_VERSION)?
PKG_HASH:=04a9842de9003f9033c8cbff2262d860e740fe23c0fffc1db50463a599552fb8
PKG_BUILD_DIR:=$(BUILD_DIR)/dldns-$(DLDNS_SOURCE_VERSION)

PKG_LICENSE:=MIT
PKG_URL:=https://github.com/erning/dldns
PKG_MAINTAINER:=Zhang Erning <zhang@erning.com>

include $(INCLUDE_DIR)/package.mk

define Package/swanpan-dldns
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Swanpan
  TITLE:=Linode dynamic DNS manager
  DEPENDS:=+ca-bundle +curl +jsonfilter
  PKGARCH:=all
endef

define Package/swanpan-dldns/description
 Installs the dldns OpenWrt shell client for synchronizing Linode A and AAAA
 records from network interface addresses.
endef

define Package/swanpan-dldns/conffiles
/etc/config/dldns
endef

define Build/Compile
endef

define Package/swanpan-dldns/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/dldns $(1)/usr/bin/dldns

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/dldns.config $(1)/etc/config/dldns
endef

$(eval $(call BuildPackage,swanpan-dldns))
