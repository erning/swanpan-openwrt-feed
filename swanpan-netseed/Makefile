include $(TOPDIR)/rules.mk

PKG_NAME:=swanpan-netseed
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

# Commit referenced by v1.0.0.
NETSEED_SOURCE_VERSION:=58264926259bb6bf4461f7b0a1041d8d83156177
PKG_SOURCE:=netseed-$(NETSEED_SOURCE_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/erning/netseed/tar.gz/$(NETSEED_SOURCE_VERSION)?
PKG_HASH:=1a24281f4e92a01a7494818f143c645bbd34977b523e35d87539b3b74580ce8a
PKG_BUILD_DIR:=$(BUILD_DIR)/netseed-$(NETSEED_SOURCE_VERSION)

NETSEED_CONFIG_FILES:= \
	chnlist.conf \
	chnlist6.conf \
	gfwlist.conf \
	gfwlist6.conf

PKG_LICENSE:=Proprietary
PKG_URL:=https://github.com/erning/netseed
PKG_MAINTAINER:=Zhang Erning <zhang@erning.com>

include $(INCLUDE_DIR)/package.mk

define Package/swanpan-netseed
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Swanpan
  TITLE:=ipset preset manager
  DEPENDS:=+ipset
  PKGARCH:=all
endef

define Package/swanpan-netseed/description
 Installs the netseed ipset preset manager and loads all configured presets
 before mwan3 starts during boot.
endef

define Package/swanpan-netseed/conffiles
/etc/netseed/
endef

define Build/Compile
endef

define Package/swanpan-netseed/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/netseed $(1)/usr/sbin/netseed

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/netseed.init $(1)/etc/init.d/netseed

	$(INSTALL_DIR) $(1)/etc/netseed
	$(INSTALL_CONF) $(addprefix ./files/,$(NETSEED_CONFIG_FILES)) \
		$(1)/etc/netseed/
endef

$(eval $(call BuildPackage,swanpan-netseed))
