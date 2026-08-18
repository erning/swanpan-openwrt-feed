# Swanpan OpenWrt Feed

本仓库提供 Swanpan 维护的 OpenWrt 软件包，主要面向使用 APK 包管理器的 OpenWrt
25.12，并按目标架构提供预编译的 ChinaDNS-NG。此外，也支持为 GL-E5800 和 GL-BE3600
的厂商固件构建特定的软件包组合。

## 软件包

| 软件包 | 作用 |
|---|---|
| `swanpan-usb-wan-name` | 将支持的 USB WAN 网络设备重命名为 `cellular0` |
| `swanpan-chnroute` | 下载、验证、持久化并恢复 IPv4 和 IPv6 CIDR ipset |
| `swanpan-chinadns-ng` | 安装与目标架构匹配的静态 ChinaDNS-NG、默认配置和 procd 服务 |
| `swanpan-mwan3-patch` | 为 mwan3 规则增加基于源地址 ipset 的匹配条件 |
| `swanpan-luci-app-mwan3-patch` | 在 LuCI 的 mwan3 规则界面中增加源地址 ipset 字段 |

`swanpan-chnroute` 在构建时包含一份固定提交的初始数据。因此，新安装无需先联网下载
CIDR 数据即可恢复 ipset；安装后仍可运行 `chnroute update` 获取新数据。

`swanpan-chinadns-ng` 不编译上游代码。OpenWrt 构建系统会从固定的 GitHub Release
下载与 `ARCH`、ARM 版本、浮点 ABI 和 x86 子目标匹配的静态二进制，并使用 Makefile
中对应的 SHA-256 进行校验。当前支持 AArch64、ARM、i386、MIPS、MIPS64、RISC-V 64
和 x86-64。

两个 mwan3 补丁包会在目标设备上修改已安装的软件包文件。后端包按
`/lib/mwan3/mwan3.sh` 的内容选择兼容补丁，LuCI 包按已安装版本选择预生成的界面覆盖
文件。升级 `mwan3` 或 `luci-app-mwan3` 后，需要重新安装对应补丁包。

## 添加 Feed

远程仓库：

```text
src-git swanpan https://github.com/erning/swanpan-openwrt-feed.git
```

本地开发：

```text
src-link swanpan /absolute/path/swanpan-openwrt-feed
```

将对应条目加入 OpenWrt 或 SDK 的 `feeds.conf.default` 后执行：

```sh
./scripts/feeds update swanpan
./scripts/feeds install -a -p swanpan
```

## 构建

### 设备预设

根目录的 `justfile` 提供按设备维护的构建配置。常规设备配方默认使用 OpenWrt 25.12.5。
常规 GL.iNet 配方构建全部 5 个软件包；Ubiquiti 配方不构建
`swanpan-usb-wan-name`，仅构建其余 4 个软件包。E5800 配方默认使用 OpenWrt 23.05.4，
仅构建 `swanpan-chnroute`；BE3600 配方默认使用 OpenWrt 23.05.6，构建
`swanpan-chnroute` 和 `swanpan-chinadns-ng`：

| 配方 | 设备 | Target | 软件包架构 |
| --- | --- | --- | --- |
| `MT3600BE` | GL-MT3600BE | `mediatek/filogic` | `aarch64_cortex-a53` |
| `MT3000` | GL-MT3000 | `mediatek/filogic` | `aarch64_cortex-a53` |
| `MT2500` | GL-MT2500 | `mediatek/filogic` | `aarch64_cortex-a53` |
| `XE300` | GL-XE300 | `ath79/nand` | `mips_24kc` |
| `E5800` | GL-E5800 | `sdx75/generic`（厂商） | `aarch64_cortex-a53` |
| `BE3600` | GL-BE3600 | `ipq53xx`（厂商 QSDK） | `aarch64_cortex-a53_neon-vfpv4` |
| `ERX` | Ubiquiti EdgeRouter X | `ramips/mt7621` | `mipsel_24kc` |
| `ER4` | Ubiquiti EdgeRouter 4 | `octeon/generic` | `mips64_octeonplus` |
| `ERLITE` | Ubiquiti EdgeRouter Lite | `octeon/generic` | `mips64_octeonplus` |
| `USG` | Ubiquiti UniFi Security Gateway | `octeon/generic` | `mips64_octeonplus` |

```sh
just MT3600BE
just XE300
just E5800
just E5800 23.05.6
just BE3600
just ERX
just ER4 25.12.2
```

最后一条命令会改用 OpenWrt 25.12.2。常规设备配方的版本号同时用于选择 SDK 镜像和产物
目录，例如 `dist/ER4/25.12.2/`。E5800 和 BE3600 的版本参数只选择兼容 SDK，产物目录
分别使用带 `vendor-` 前缀的厂商固件版本 `dist/E5800/vendor-4.8.5/` 和
`dist/BE3600/vendor-4.9.0/`。直接运行 `just` 或
`just --list` 可以查看所有设备配方。

GL.iNet 的[E5800 stable 下载页](https://dl.gl-inet.com/router/e5800/stable)将最新发布固件
列为 4.8.5，[固件版本表](https://www.gl-inet.com/en-gb/pages/firmware-versions)将其标注为
QuecOpen SDK、OpenWrt 23.05.4；设备使用厂商的 `sdx75/generic` target，上游没有对应的
OpenWrt SDK。`E5800` 配方借用同为
`aarch64_cortex-a53` 的[官方
`mediatek/filogic` SDK](https://downloads.openwrt.org/releases/23.05.4/targets/mediatek/filogic/)
作为打包环境。这样做仅适用于不含目标相关二进制、声明为 `PKGARCH:=all` 的
`swanpan-chnroute`，不能用于构建 E5800 固件、内核模块或目标相关软件包。产物写入
`dist/E5800/vendor-4.8.5/`。可以将版本号作为位置参数传给配方；该参数只改变兼容 SDK，不改变
设备厂商固件的 OpenWrt 基线或产物目录。

GL.iNet 的[固件版本表](https://www.gl-inet.com/en-us/pages/firmware-versions/)将 GL-BE3600
最新发布固件列为 4.9.0，并标注 QSDK、OpenWrt 23.05；设备运行 OpenWrt
23.05-SNAPSHOT，上游没有对应的 `ipq53xx` SDK。`BE3600` 配方默认借用官方 OpenWrt
23.05.6 的 `mediatek/filogic` SDK，该版本是兼容打包环境，并非厂商固件标注的精确补丁
版本。配方只打包与内核和 QSDK 无关的 chnroute，以及包含静态 AArch64 二进制的
ChinaDNS-NG。该 SDK 生成的架构名称是 `aarch64_cortex-a53`，与厂商使用的
`aarch64_cortex-a53_neon-vfpv4` 名称不同；安装前需要按下文配置 `opkg`。该配方不能
用于编译内核模块或动态链接的目标相关程序。产物写入 `dist/BE3600/vendor-4.9.0/`。

### 使用 SDK 容器

`scripts/build-sdk.sh` 使用官方 OpenWrt SDK 镜像构建指定软件包。启动 Docker 后，在仓库
根目录运行：

```sh
OPENWRT_VERSION="25.12.2" \
SDK_IMAGE="openwrt/sdk:mediatek-filogic-25.12.2" \
PACKAGES="swanpan-chinadns-ng swanpan-mwan3-patch luci-app-mwan3-patch" \
OUTPUT_DIR="dist/25.12.2/mediatek-filogic" \
./scripts/build-sdk.sh
```

脚本会将仓库以只读方式挂载为本地 Feed，检查 SDK 内的 OpenWrt 版本，依次构建指定包及
其 Swanpan 依赖包，并将 APK 或 IPK 以及 `build.env` 写入
`dist/25.12.2/mediatek-filogic/`。示例中的简写 `luci-app-mwan3-patch` 会解析为实际包名
`swanpan-luci-app-mwan3-patch`。构建成功后，该产物目录中原有的 Swanpan APK 或 IPK
会被本次结果替换。

命令行中，每个软件包使用一个可重复的 `--package` 参数：

```sh
./scripts/build-sdk.sh \
  --openwrt-version 25.12.2 \
  --sdk-image openwrt/sdk:mediatek-filogic-25.12.2 \
  --package swanpan-chinadns-ng \
  --package swanpan-mwan3-patch \
  --package luci-app-mwan3-patch \
  --output dist/25.12.2/mediatek-filogic
```

一旦指定 `--package`，命令行中的软件包列表会覆盖 `PACKAGES` 环境变量。版本、SDK 镜像、
软件包和产物目录均须显式提供。`JOBS`、`SDK_PLATFORM` 和 `PULL_POLICY` 是可选设置；未
提供时，脚本不会传递对应参数。当前官方 SDK 镜像仅提供 `linux/amd64` 版本，因此
Apple Silicon 主机应显式设置 `SDK_PLATFORM=linux/amd64` 或
`--platform linux/amd64`。运行 `./scripts/build-sdk.sh --help` 查看完整选项。

### 手动构建

使用与目标设备版本、target 和 subtarget 一致的 OpenWrt SDK。根据需要分别构建软件包：

```sh
make defconfig
make package/feeds/swanpan/swanpan-usb-wan-name/compile V=s
make package/feeds/swanpan/swanpan-chnroute/compile V=s
make package/feeds/swanpan/swanpan-chinadns-ng/compile V=s
make package/feeds/swanpan/swanpan-mwan3-patch/compile V=s
make package/feeds/swanpan/swanpan-luci-app-mwan3-patch/compile V=s
```

OpenWrt 25.12 生成 `.apk`，OpenWrt 23.05 生成 `.ipk`。产物位于：

```text
bin/packages/<architecture>/swanpan/
```

如果需要生成可作为软件源使用的索引，再执行：

```sh
make package/index
```

## 安装

E5800 使用 `opkg`。先确认设备版本和软件包架构，再安装依赖及构建出的 IPK：

```sh
cat /etc/openwrt_release
opkg print-architecture
opkg update
opkg install curl flock ipset
opkg install /tmp/swanpan-chnroute_*.ipk
```

BE3600 的厂商 `opkg` 默认只接受 `aarch64_cortex-a53_neon-vfpv4`。先检查架构列表；如果
缺少 `aarch64_cortex-a53`，将其以较低优先级加入 `/etc/opkg.conf`，再安装两个软件包：

```sh
opkg print-architecture
grep -q '^arch aarch64_cortex-a53 ' /etc/opkg.conf || \
  printf '%s\n' 'arch aarch64_cortex-a53 5' >> /etc/opkg.conf
opkg update
opkg install curl flock ipset
opkg install \
  /tmp/swanpan-chnroute_*.ipk \
  /tmp/swanpan-chinadns-ng_*.ipk
```

不要使用 `--force-depends` 绕过依赖检查。以下安装命令适用于 OpenWrt 25.12。

未配置 Swanpan 软件源时，将需要的 `.apk` 复制到路由器。USB WAN 重命名包可以单独安装：

```sh
apk add --allow-untrusted /tmp/swanpan-usb-wan-name-*.apk
```

ChinaDNS-NG 依赖 chnroute，因此安装本地 APK 时需要同时提供这两个软件包：

```sh
apk add --allow-untrusted \
  /tmp/swanpan-chnroute-*.apk \
  /tmp/swanpan-chinadns-ng-*.apk
```

安装 mwan3 后端和 LuCI 补丁时，可以同时提供两个本地 APK；其余依赖由已配置的软件源
解析：

```sh
apk add --allow-untrusted \
  /tmp/swanpan-mwan3-patch-*.apk \
  /tmp/swanpan-luci-app-mwan3-patch-*.apk
```

配置并信任 Swanpan 软件源后，可以按需安装：

```sh
apk add swanpan-usb-wan-name
apk add swanpan-chnroute
apk add swanpan-chinadns-ng
apk add swanpan-mwan3-patch
apk add swanpan-luci-app-mwan3-patch
```

OpenWrt 会自动启用并启动软件包中的 init 服务。`/etc/chinadns-ng.conf`、
`/etc/chinadns-ng/` 下的域名列表以及 `/etc/chnroute/` 被声明为配置文件，升级软件包时
保留设备上的修改和运行时数据。

## 上游版本更新

更新 `swanpan-chnroute` 时，需要同时固定新的 `dist` 提交、归档 SHA-256 和软件包版本。
更新 `swanpan-chinadns-ng` 时，需要同时固定 Release 标签、资产名称、资产 SHA-256 和
软件包版本，并核对所有架构映射。不要使用 `latest/download` 或跳过哈希校验。

更新 mwan3 后端补丁时，需要针对目标分支的 `mwan3.sh` 验证补丁选择、安装和卸载恢复。
LuCI 规则界面发生变化时，运行
`swanpan-luci-app-mwan3-patch/tools/gen-overlay.sh <ref>` 生成或验证对应覆盖文件。
