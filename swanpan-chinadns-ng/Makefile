include $(TOPDIR)/rules.mk

PKG_NAME:=swanpan-chinadns-ng
PKG_VERSION:=2026.08.16
PKG_RELEASE:=3

CHINADNS_RELEASE_TAG:=2026.08.16-c

ifeq ($(ARCH),aarch64)
  CHINADNS_ASSET:=chinadns-ng+wolfssl@aarch64-linux-musl@generic+v8a@fast+lto
  CHINADNS_HASH:=d205f4656ea59259a717c449869cfdf5d9d9de10bfffa285aa4d44435a17c2aa
else ifeq ($(ARCH),arm)
  ifeq ($(CONFIG_arm_v7),y)
    ifeq ($(CONFIG_SOFT_FLOAT),y)
      CHINADNS_ASSET:=chinadns-ng+wolfssl@arm-linux-musleabi@generic+v7a@fast+lto
      CHINADNS_HASH:=45a95e720a7705a67f951720fef619a3e3fc5934b4dd35fc2128280758a4a9b7
    else
      CHINADNS_ASSET:=chinadns-ng+wolfssl@arm-linux-musleabihf@generic+v7a@fast+lto
      CHINADNS_HASH:=d30f616dba4ab2c51db7a0234321acfd8e30496741216d9f181b159eb6da6f31
    endif
  else ifeq ($(CONFIG_arm_v6),y)
    CHINADNS_ASSET:=chinadns-ng+wolfssl@arm-linux-musleabi@generic+v6+soft_float@fast+lto
    CHINADNS_HASH:=2faf7fdac1c05f945012086a3b07ed0e492e99c2f443ca1e00520e4496e810ab
  else
    CHINADNS_ASSET:=chinadns-ng+wolfssl@arm-linux-musleabi@generic+v5t+soft_float@fast+lto
    CHINADNS_HASH:=649567525e386f99bfc3ecd652a55c64bfcda28bd61e9bd053088a2c48d6f572
  endif
else ifeq ($(ARCH),i386)
  ifneq ($(CONFIG_TARGET_x86_geode)$(CONFIG_TARGET_x86_legacy),)
    CHINADNS_ASSET:=chinadns-ng+wolfssl@i386-linux-musl@i686@fast+lto
    CHINADNS_HASH:=ec1ca495426288ec9c1e1a3d07964ed76cf3f752caafea72048030d4af33e50c
  else
    CHINADNS_ASSET:=chinadns-ng+wolfssl@i386-linux-musl@pentium4@fast+lto
    CHINADNS_HASH:=9aa72e0688582b88ac72a441df6b017da9d662c0084cfd23fd06c64e59a5e1c5
  endif
else ifeq ($(ARCH),mips)
  ifeq ($(CONFIG_SOFT_FLOAT),y)
    CHINADNS_ASSET:=chinadns-ng+wolfssl@mips-linux-musl@mips32+soft_float@fast+lto
    CHINADNS_HASH:=d87fe622377c8a77ce90eebf217db341cdc1012eeeab0df44653a91f120d6414
  else
    CHINADNS_ASSET:=chinadns-ng+wolfssl@mips-linux-musl@mips32@fast+lto
    CHINADNS_HASH:=602e2e56ce99254e2358e9e07e6ef542b3928f90720dcf2ebf0a3a8a33e35bef
  endif
else ifeq ($(ARCH),mipsel)
  ifeq ($(CONFIG_SOFT_FLOAT),y)
    CHINADNS_ASSET:=chinadns-ng+wolfssl@mipsel-linux-musl@mips32+soft_float@fast+lto
    CHINADNS_HASH:=256b96fb26914f65e88e1b7b840719dba19b929117639da1944e0ae296518633
  else
    CHINADNS_ASSET:=chinadns-ng+wolfssl@mipsel-linux-musl@mips32@fast+lto
    CHINADNS_HASH:=3a2bd55f28800a916d6a100f9e8db5f4f155de7a744a5b91bc2164dfb99a26a1
  endif
else ifeq ($(ARCH),mips64)
  ifeq ($(CONFIG_SOFT_FLOAT),y)
    CHINADNS_ASSET:=chinadns-ng+wolfssl@mips64-linux-musl@mips64+soft_float@fast
    CHINADNS_HASH:=a627f1b0d55a291330f9b75d648b650616702cc58af6bde6f8b0523b8a27dd6c
  else
    CHINADNS_ASSET:=chinadns-ng+wolfssl@mips64-linux-musl@mips64@fast+lto
    CHINADNS_HASH:=aa71fdab406fd3cf33477dacbe02ac055af91d5e7a93e0c0b2530e9c29c6aea1
  endif
else ifeq ($(ARCH),mips64el)
  ifeq ($(CONFIG_SOFT_FLOAT),y)
    CHINADNS_ASSET:=chinadns-ng+wolfssl@mips64el-linux-musl@mips64+soft_float@fast
    CHINADNS_HASH:=7fb54b9d6bac5ce4f444b6ac421af41b3893ae55b3f869c409b8ce5abbd8eebf
  else
    CHINADNS_ASSET:=chinadns-ng+wolfssl@mips64el-linux-musl@mips64@fast+lto
    CHINADNS_HASH:=8dcbd68caf70c838f93e691e4e3b34bedd771826707e4d87a86ae921552b7032
  endif
else ifeq ($(ARCH),riscv64)
  CHINADNS_ASSET:=chinadns-ng+wolfssl@riscv64-linux-musl@baseline_rv64@fast+lto
  CHINADNS_HASH:=321b95caf8c49b3a8d91e8966e54c199587271f4a9250b5cd13d4be62a28c059
else ifeq ($(ARCH),x86_64)
  CHINADNS_ASSET:=chinadns-ng+wolfssl@x86_64-linux-musl@x86_64@fast+lto
  CHINADNS_HASH:=9d477aa55f3d7106f7e8ab5076ab94e807effdd43967fae9642d15123fe2d876
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
