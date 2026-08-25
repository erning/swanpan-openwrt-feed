include $(TOPDIR)/rules.mk

PKG_NAME:=swanpan-luci-app-mwan3-patch
PKG_VERSION:=1.0.0
PKG_RELEASE:=4

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Zhang Erning <zhang@erning.com>

include $(INCLUDE_DIR)/package.mk

define Package/swanpan-luci-app-mwan3-patch
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI source ipset and local traffic patch for mwan3
  DEPENDS:=+luci-app-mwan3 +swanpan-mwan3-patch
  CONFLICTS:=luci-app-mwan3-src-ipset
  PKGARCH:=all
endef

define Package/swanpan-luci-app-mwan3-patch/description
 Adds "ipset_src" and "ipset_src_local" UI support to luci-app-mwan3
 rules by installing a content-matched LuCI overlay on the target device.
endef

define Package/swanpan-luci-app-mwan3-patch/install
	$(INSTALL_DIR) $(1)/usr/share/swanpan-luci-app-mwan3-patch/overlays
	$(CP) ./files/usr/share/swanpan-luci-app-mwan3-patch/overlays/* \
		$(1)/usr/share/swanpan-luci-app-mwan3-patch/overlays/

	$(INSTALL_DIR) $(1)/usr/libexec/swanpan-luci-app-mwan3-patch
	$(INSTALL_BIN) ./files/usr/libexec/swanpan-luci-app-mwan3-patch/apply-overlay.sh \
		$(1)/usr/libexec/swanpan-luci-app-mwan3-patch/apply-overlay.sh
	$(INSTALL_BIN) ./files/usr/libexec/swanpan-luci-app-mwan3-patch/postinst.sh \
		$(1)/usr/libexec/swanpan-luci-app-mwan3-patch/postinst.sh
	$(INSTALL_BIN) ./files/usr/libexec/swanpan-luci-app-mwan3-patch/postrm.sh \
		$(1)/usr/libexec/swanpan-luci-app-mwan3-patch/postrm.sh
endef

define Package/swanpan-luci-app-mwan3-patch/postinst
#!/bin/sh
set -eu

root="$${IPKG_INSTROOT:-}"
script="$${root}/usr/libexec/swanpan-luci-app-mwan3-patch/postinst.sh"

[ -x "$${script}" ] || exit 0
"$${script}"
exit 0
endef

define Package/swanpan-luci-app-mwan3-patch/postrm
#!/bin/sh
set -eu

root="$${IPKG_INSTROOT:-}"
script="$${root}/usr/libexec/swanpan-luci-app-mwan3-patch/postrm.sh"

[ -x "$${script}" ] || exit 0
"$${script}"
exit 0
endef

define Build/Compile
endef

$(eval $(call BuildPackage,swanpan-luci-app-mwan3-patch))
