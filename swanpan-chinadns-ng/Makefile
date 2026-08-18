include $(TOPDIR)/rules.mk

PKG_NAME:=swanpan-chinadns-ng
PKG_VERSION:=2026.08.16
PKG_RELEASE:=2

CHINADNS_RELEASE_TAG:=2026.08.16-c

ifeq ($(ARCH),aarch64)
  CHINADNS_ASSET:=chinadns-ng@aarch64-linux-musl@generic+v8a@fast+lto
  CHINADNS_HASH:=2b4d53e6a9de902fc1cf7fa486e3442622e3601ca6c70d527b5918dcd7a737a8
else ifeq ($(ARCH),arm)
  ifeq ($(CONFIG_arm_v7),y)
    ifeq ($(CONFIG_SOFT_FLOAT),y)
      CHINADNS_ASSET:=chinadns-ng@arm-linux-musleabi@generic+v7a@fast+lto
      CHINADNS_HASH:=a0ff1a1d5b4aec4cec04c43168b3366c8dab7d40da049f270d778d0649ed90bd
    else
      CHINADNS_ASSET:=chinadns-ng@arm-linux-musleabihf@generic+v7a@fast+lto
      CHINADNS_HASH:=dc0f231bf704734b511fbd53596e523f867c3711a279a422a59b225723ce4cb4
    endif
  else ifeq ($(CONFIG_arm_v6),y)
    CHINADNS_ASSET:=chinadns-ng@arm-linux-musleabi@generic+v6+soft_float@fast+lto
    CHINADNS_HASH:=3960cde85b2ace228ad4a19b61f7932019c7be07310c2a326f2e1772e2135942
  else
    CHINADNS_ASSET:=chinadns-ng@arm-linux-musleabi@generic+v5t+soft_float@fast+lto
    CHINADNS_HASH:=83d9a8e35699842adc54c3aed85c8c5f1ef48ff8afa1c9de2b696dd64845b7d4
  endif
else ifeq ($(ARCH),i386)
  ifneq ($(CONFIG_TARGET_x86_geode)$(CONFIG_TARGET_x86_legacy),)
    CHINADNS_ASSET:=chinadns-ng@i386-linux-musl@i686@fast+lto
    CHINADNS_HASH:=6c562e6b9eac94c7959f22d6bbb6635b09d4943ee98439aab931996d7880ffaa
  else
    CHINADNS_ASSET:=chinadns-ng@i386-linux-musl@pentium4@fast+lto
    CHINADNS_HASH:=0e77fd6321a2789e1a4d766a1b4b9994b33e66778cceaa47d173c7358b04f650
  endif
else ifeq ($(ARCH),mips)
  ifeq ($(CONFIG_SOFT_FLOAT),y)
    CHINADNS_ASSET:=chinadns-ng@mips-linux-musl@mips32+soft_float@fast+lto
    CHINADNS_HASH:=fc73e646a5c24978b66614f7b9514ff061b20425e3b5a1b629eefa28d6e0bf3a
  else
    CHINADNS_ASSET:=chinadns-ng@mips-linux-musl@mips32@fast+lto
    CHINADNS_HASH:=d7bd3188bba58b37dee222a0807694dfc3a3c41b6d070fb14eac3e9b9bd75b87
  endif
else ifeq ($(ARCH),mipsel)
  ifeq ($(CONFIG_SOFT_FLOAT),y)
    CHINADNS_ASSET:=chinadns-ng@mipsel-linux-musl@mips32+soft_float@fast+lto
    CHINADNS_HASH:=e577e62e5b60b26772f88d7d63b4db39001785bc067c5e758dea933243e79914
  else
    CHINADNS_ASSET:=chinadns-ng@mipsel-linux-musl@mips32@fast+lto
    CHINADNS_HASH:=0156c647e30d4cb68874c75ba6d0597ea49e435768e6a13ffa72b9cc3b52fd22
  endif
else ifeq ($(ARCH),mips64)
  ifeq ($(CONFIG_SOFT_FLOAT),y)
    CHINADNS_ASSET:=chinadns-ng@mips64-linux-musl@mips64+soft_float@fast
    CHINADNS_HASH:=7183383ad7fb383e3350377415b816540fb41cbf6d73554bfa02ec40f112ed51
  else
    CHINADNS_ASSET:=chinadns-ng@mips64-linux-musl@mips64@fast+lto
    CHINADNS_HASH:=b571c310cf62d9ef1c5dcba4b31e0ff9fafb246681ca3132060677a20877edcb
  endif
else ifeq ($(ARCH),mips64el)
  ifeq ($(CONFIG_SOFT_FLOAT),y)
    CHINADNS_ASSET:=chinadns-ng@mips64el-linux-musl@mips64+soft_float@fast
    CHINADNS_HASH:=4faacbd8956fdc66d63afd52db0d60e342821c3c595a32625591377ecf9b1e98
  else
    CHINADNS_ASSET:=chinadns-ng@mips64el-linux-musl@mips64@fast+lto
    CHINADNS_HASH:=b7e0dbec3ea0ccc1fbe977a8f8af81d2633807c19b7e0e658cc1ab98e6f247a4
  endif
else ifeq ($(ARCH),riscv64)
  CHINADNS_ASSET:=chinadns-ng@riscv64-linux-musl@baseline_rv64@fast+lto
  CHINADNS_HASH:=2872db5b16c6e3437551ed3af20367a356c7007ebe30046e1c57db67a6d89e38
else ifeq ($(ARCH),x86_64)
  CHINADNS_ASSET:=chinadns-ng@x86_64-linux-musl@x86_64@fast+lto
  CHINADNS_HASH:=61788c3f0897efd58b97ed3a93f0fc53d18d4d84e6b61c20ef12d05de4d1cf71
else
  CHINADNS_ASSET:=unsupported-$(ARCH)
  CHINADNS_HASH:=dummy
endif

CHINADNS_DL_FILE:=$(subst chinadns-ng,chinadns-ng-$(CHINADNS_RELEASE_TAG),$(CHINADNS_ASSET))

PKG_LICENSE:=AGPL-3.0-only
PKG_URL:=https://github.com/erning/chinadns-ng

include $(INCLUDE_DIR)/package.mk

define Package/swanpan-chinadns-ng
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Swanpan
  TITLE:=ChinaDNS-NG static release
  DEPENDS:=@(aarch64||arm||i386||mips||mipsel||mips64||mips64el||riscv64||x86_64) +swanpan-chnroute
endef

define Package/swanpan-chinadns-ng/description
 Installs a verified, target-specific static ChinaDNS-NG release together with
 the Swanpan default configuration and procd service.
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
