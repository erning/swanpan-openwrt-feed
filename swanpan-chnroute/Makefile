include $(TOPDIR)/rules.mk

PKG_NAME:=swanpan-chnroute
PKG_VERSION:=2026.08.17
PKG_RELEASE:=1

CHNROUTE_SOURCE_VERSION:=4d1003c7b5d50aa701fe694c7e27718e8c0d7ff0
PKG_SOURCE:=chnroute-$(CHNROUTE_SOURCE_VERSION).tar.gz
PKG_SOURCE_URL:=https://codeload.github.com/erning/chnroute/tar.gz/$(CHNROUTE_SOURCE_VERSION)?
PKG_HASH:=0a3e4e1dc85733c5caa22aa6676fa9f2eaa3b0c11812c1e38a4368de726e436b
PKG_BUILD_DIR:=$(BUILD_DIR)/chnroute-$(CHNROUTE_SOURCE_VERSION)

PKG_LICENSE:=Proprietary
PKG_URL:=https://github.com/erning/chnroute

CHNROUTE_DATA_FILES:= \
	chnroute.txt \
	chnroute6.txt \
	non-chnroute.txt \
	non-chnroute6.txt \
	china-telecom.txt \
	china-telecom6.txt \
	china-mobile.txt \
	china-mobile6.txt \
	china-unicom.txt \
	china-unicom6.txt \
	china-other.txt \
	china-other6.txt \
	private.txt \
	private6.txt \
	special.txt \
	special6.txt

include $(INCLUDE_DIR)/package.mk

define Package/swanpan-chnroute
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Swanpan
  TITLE:=Verified China route ipset manager
  DEPENDS:=+curl +flock +ipset
  PKGARCH:=all
endef

define Package/swanpan-chnroute/description
 Downloads, verifies, persists, and atomically restores IPv4 and IPv6 CIDR
 lists as traditional kernel ipsets.
endef

define Package/swanpan-chnroute/conffiles
/etc/chnroute/
endef

define Build/Compile
endef

define Package/swanpan-chnroute/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/chnroute $(1)/usr/sbin/chnroute

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/chnroute.init $(1)/etc/init.d/chnroute

	$(INSTALL_DIR) $(1)/etc/chnroute
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/manifest.json $(1)/etc/chnroute/
	$(INSTALL_DATA) $(addprefix $(PKG_BUILD_DIR)/,$(CHNROUTE_DATA_FILES)) \
		$(1)/etc/chnroute/
endef

$(eval $(call BuildPackage,swanpan-chnroute))
