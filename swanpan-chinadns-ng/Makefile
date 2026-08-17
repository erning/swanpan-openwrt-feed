include $(TOPDIR)/rules.mk

PKG_NAME:=swanpan-chinadns-ng
PKG_VERSION:=2026.08.16
PKG_RELEASE:=1

CHINADNS_RELEASE_TAG:=2026.08.16-c
CHINADNS_ASSET:=chinadns-ng@aarch64-linux-musl@generic+v8a@fast+lto
CHINADNS_DL_FILE:=chinadns-ng-$(CHINADNS_RELEASE_TAG)-aarch64-v8a
CHINADNS_HASH:=2b4d53e6a9de902fc1cf7fa486e3442622e3601ca6c70d527b5918dcd7a737a8

PKG_LICENSE:=AGPL-3.0-only
PKG_URL:=https://github.com/erning/chinadns-ng

include $(INCLUDE_DIR)/package.mk

define Package/swanpan-chinadns-ng
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Swanpan
  TITLE:=ChinaDNS-NG static AArch64 release
  DEPENDS:=@aarch64 +swanpan-chnroute
endef

define Package/swanpan-chinadns-ng/description
 Installs a verified, statically linked AArch64 ChinaDNS-NG release together
 with the Swanpan default configuration and procd service.
endef

define Package/swanpan-chinadns-ng/conffiles
/etc/chinadns-ng.conf
/etc/chinadns-ng/chnlist.txt
/etc/chinadns-ng/gfwlist.txt
endef

define Download/chinadns-ng
  URL:=https://github.com/erning/chinadns-ng/releases/download/$(CHINADNS_RELEASE_TAG)/
  URL_FILE:=$(CHINADNS_ASSET)
  FILE:=$(CHINADNS_DL_FILE)
  HASH:=$(CHINADNS_HASH)
endef

define Build/Prepare
	rm -rf $(PKG_BUILD_DIR)
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/$(CHINADNS_DL_FILE) $(PKG_BUILD_DIR)/chinadns-ng
endef

define Build/Compile
endef

define Package/swanpan-chinadns-ng/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/chinadns-ng $(1)/usr/sbin/chinadns-ng

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/chinadns-ng.init $(1)/etc/init.d/chinadns-ng

	$(INSTALL_DIR) $(1)/etc/chinadns-ng
	touch $(1)/etc/chinadns-ng/chnlist.txt
	touch $(1)/etc/chinadns-ng/gfwlist.txt
	$(INSTALL_CONF) ./files/chinadns-ng.conf $(1)/etc/chinadns-ng.conf
endef

$(eval $(call Download,chinadns-ng))
$(eval $(call BuildPackage,swanpan-chinadns-ng))
