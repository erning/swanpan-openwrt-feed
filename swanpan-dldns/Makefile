include $(TOPDIR)/rules.mk

PKG_NAME:=swanpan-dldns
PKG_VERSION:=0.5.0
PKG_RELEASE:=1

DLDNS_SOURCE_VERSION:=adba49de392e7f5e1fd4ccab2035ab0fdcd93867
PKG_SOURCE:=dldns-$(DLDNS_SOURCE_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/erning/dldns/tar.gz/$(DLDNS_SOURCE_VERSION)?
PKG_HASH:=a7169d25b443b194a61ecbc99a36028b8134772cd6c564ebd60479e8d6ddfbb3
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
