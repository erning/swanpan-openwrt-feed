include $(TOPDIR)/rules.mk

PKG_NAME:=swanpan-mwan3-patch
PKG_VERSION:=1.0.0
PKG_RELEASE:=3

PKG_LICENSE:=GPL-2.0-only
PKG_MAINTAINER:=Zhang Erning <zhang@erning.com>

include $(INCLUDE_DIR)/package.mk

define Package/swanpan-mwan3-patch
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Routing and Redirection
  TITLE:=Source ipset and local traffic matching patch for mwan3
  DEPENDS:=+mwan3 +patch
  CONFLICTS:=mwan3-src-ipset
  PKGARCH:=all
endef

define Package/swanpan-mwan3-patch/description
 Adds "ipset_src" and "ipset_src_local" support to mwan3 rules by
 patching /lib/mwan3/mwan3.sh on the target device.
endef

define Package/swanpan-mwan3-patch/install
	$(INSTALL_DIR) $(1)/usr/share/swanpan-mwan3-patch/patches
	$(CP) ./files/usr/share/swanpan-mwan3-patch/patches/*.patch \
		$(1)/usr/share/swanpan-mwan3-patch/patches/
	$(INSTALL_DIR) $(1)/usr/share/swanpan-mwan3-patch/patches-local
	$(CP) ./files/usr/share/swanpan-mwan3-patch/patches-local/*.patch \
		$(1)/usr/share/swanpan-mwan3-patch/patches-local/

	$(INSTALL_DIR) $(1)/usr/libexec/swanpan-mwan3-patch
	$(INSTALL_BIN) ./files/usr/libexec/swanpan-mwan3-patch/postinst.sh \
		$(1)/usr/libexec/swanpan-mwan3-patch/postinst.sh
	$(INSTALL_BIN) ./files/usr/libexec/swanpan-mwan3-patch/postrm.sh \
		$(1)/usr/libexec/swanpan-mwan3-patch/postrm.sh
endef

define Package/swanpan-mwan3-patch/postinst
#!/bin/sh
set -eu

root="$${IPKG_INSTROOT:-}"
script="$${root}/usr/libexec/swanpan-mwan3-patch/postinst.sh"

[ -x "$${script}" ] || exit 0
"$${script}"
exit 0
endef

define Package/swanpan-mwan3-patch/postrm
#!/bin/sh
set -eu

root="$${IPKG_INSTROOT:-}"
script="$${root}/usr/libexec/swanpan-mwan3-patch/postrm.sh"

[ -x "$${script}" ] || exit 0
"$${script}"
exit 0
endef

define Build/Compile
endef

$(eval $(call BuildPackage,swanpan-mwan3-patch))
