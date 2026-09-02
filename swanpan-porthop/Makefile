include $(TOPDIR)/rules.mk

PKG_NAME:=swanpan-porthop
PKG_VERSION:=0.1.0
PKG_RELEASE:=1

PORTHOP_SOURCE_VERSION:=6ca43cdc2aa1d0d76a7c221e1d221e82b8610e42
PKG_SOURCE:=porthop-$(PORTHOP_SOURCE_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/erning/porthop/tar.gz/$(PORTHOP_SOURCE_VERSION)?
PKG_HASH:=8f580ef9d8a040c0a89eb6e12c367c867dadaacecced301e1b4a6a5b4d4f3efe
PKG_BUILD_DIR:=$(BUILD_DIR)/porthop-$(PORTHOP_SOURCE_VERSION)

PKG_LICENSE:=Proprietary
PKG_URL:=https://github.com/erning/porthop
PKG_MAINTAINER:=Zhang Erning <zhang@erning.com>

include $(INCLUDE_DIR)/package.mk

define Package/swanpan-porthop
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Swanpan
  TITLE:=WireGuard UDP port hopping manager
  DEPENDS:=+bash +ca-bundle +curl +flock +jsonfilter +nftables +wireguard-tools
  PKGARCH:=all
endef

define Package/swanpan-porthop/description
 Installs the porthop Bash client for coordinating WireGuard UDP entry ports
 and managing nftables port forwarding.
endef

define Build/Compile
endef

define Package/swanpan-porthop/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/porthop $(1)/usr/bin/porthop
endef

$(eval $(call BuildPackage,swanpan-porthop))
