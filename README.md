# Swanpan OpenWrt Feed

本仓库提供 Swanpan 维护的 OpenWrt 软件包，主要面向使用 APK 包管理器的 OpenWrt
25.12，并按目标架构提供预编译的 ChinaDNS-NG。此外，也支持为 GL-XE300、GL-E5800 和
GL-BE3600 的厂商固件构建特定的软件包组合。

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

### GitHub Actions 构建

推送名称以 `v` 开头的 Git 标签会自动触发完整构建，并创建同名 GitHub Release：

```sh
git tag v2026.08.19
git push origin v2026.08.19
```

标签触发的工作流固定使用 `ALL`，按 7 组不同的 SDK 环境并行构建。也可以打开仓库的
**Actions** 页面，选择 **Build and publish packages**，点击 **Run workflow**，填写一个
尚未使用的 `release_tag`，例如 `packages-2026.08.19`，然后选择 `ALL` 或单个设备配方。
手动运行时，工作流从选定的分支或提交构建，并创建 `release_tag` 对应的 Git 标签和
GitHub Release。已存在的 Release 或手动输入的标签不会被覆盖。

构建成功后，工作流自动创建一个 GitHub Release。每个设备对应一个
`swanpan-<设备>.tar.gz`，其中保留设备目录结构，并包含 APK 或 IPK 以及 `build.env`；
Release 同时提供总 `SHA256SUMS`。Release 及其下载文件不会按 Actions Artifact 的保留期限
自动过期，除非手动删除。工作流内部使用的临时 Artifact 仅用于在构建 job 和发布 job 之间
传递文件，保留 1 天。

### 设备预设

根目录的 `justfile` 提供按设备维护的构建配置。常规设备配方默认使用 OpenWrt 25.12.5。
MT3600BE 和 MT3000 配方构建全部 5 个软件包；MT2500、Ubiquiti 和 Generic x86/64
配方不构建 `swanpan-usb-wan-name`，仅构建其余 4 个软件包。XE300 和 E5800 配方分别
默认使用 OpenWrt 22.03.4 和 23.05.4；BE3600 配方默认使用 OpenWrt 23.05.6。这三个
厂商固件配方都只构建 `swanpan-chnroute`：

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
| `ERPRO` | Ubiquiti EdgeRouter Pro（ERPro-8） | `octeon/generic` | `mips64_octeonplus` |
| `ERLITE` | Ubiquiti EdgeRouter Lite | `octeon/generic` | `mips64_octeonplus` |
| `USG` | Ubiquiti UniFi Security Gateway | `octeon/generic` | `mips64_octeonplus` |
| `X86_64` | Generic x86/64 | `x86/64` | `x86_64` |

```sh
just MT3600BE
just XE300
just E5800
just E5800 23.05.6
just BE3600
just ERX
just ERPRO
just X86_64
just ER4 25.12.2
just ALL
```

其中 `just ER4 25.12.2` 会改用 OpenWrt 25.12.2。常规设备配方的版本号同时用于选择
SDK 镜像和产物目录，例如 `dist/ER4/25.12.2/`。XE300、E5800 和 BE3600 的版本参数只
选择兼容 SDK，产物目录分别使用带 `vendor-` 前缀的厂商固件版本
`dist/XE300/vendor-4.3.27/`、
`dist/E5800/vendor-4.8.5/` 和 `dist/BE3600/vendor-4.9.0/`。直接运行 `just` 或
`just --list` 可以查看所有设备配方。

`just ALL` 按顺序构建所有设备。设备配方显式使用 `dist/.cache/`：MT3600BE、MT3000
和 MT2500 共享同一套 `mediatek/filogic` 软件包缓存，ER4、ERPRO、ERLITE 和 USG
共享 `octeon/generic` 缓存。默认配置只需启动 7 个不同的 SDK 环境，而不是为 12 个
设备分别重复构建。

GL.iNet 的[XE300 stable 下载页](https://dl.gl-inet.com/router/xe300/stable)将最新发布固件
列为 4.3.27，[固件版本表](https://www.gl-inet.com/en-gb/pages/firmware-versions)将其标注为
Native OpenWrt 22.03.4。`XE300` 配方使用对应的官方 `ath79/nand` SDK，并且仅构建与
目标架构及厂商蜂窝网络配置无关、声明为 `PKGARCH:=all` 的 `swanpan-chnroute`。产物写入
`dist/XE300/vendor-4.3.27/`；版本参数只改变 SDK，不改变厂商固件基线或产物目录。

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
版本。配方只打包与内核和 QSDK 无关、声明为 `PKGARCH:=all` 的 `swanpan-chnroute`，不能
用于编译内核模块或目标相关软件包。产物写入 `dist/BE3600/vendor-4.9.0/`。

### 使用 SDK 容器

`scripts/build-sdk.sh` 使用官方 OpenWrt SDK 镜像构建指定软件包。启动 Docker 后，在仓库
根目录运行：

```sh
OPENWRT_VERSION="25.12.2" \
SDK_IMAGE="openwrt/sdk:mediatek-filogic-25.12.2" \
PACKAGES="swanpan-chinadns-ng swanpan-mwan3-patch luci-app-mwan3-patch" \
OUTPUT_DIR="dist/25.12.2/mediatek-filogic" \
CACHE_DIR="dist/.cache" \
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
  --cache-dir dist/.cache \
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

缓存仅在显式设置 `CACHE_DIR` 或 `--cache-dir` 时启用。下载文件按 SDK 镜像隔离；APK
和 IPK 按 SDK 镜像 ID、目标平台、构建源码哈希和软件包名称保存，并在命中时校验
SHA-256。修改任意软件包源码或构建脚本会自动使用新的缓存键。`build.env` 中的
`CACHE_HIT` 表示本次是否跳过了容器构建。需要强制重建软件包但保留下载缓存时，追加
`--rebuild`。

缓存行为可以使用伪 Docker 集成测试验证，无需下载 SDK 镜像：

```sh
tests/test-build-sdk-cache.sh
```

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

XE300、E5800 和 BE3600 使用 `opkg`。先确认设备版本和软件包架构，再安装依赖及构建出的
IPK：

```sh
cat /etc/openwrt_release
opkg print-architecture
opkg update
opkg install curl flock ipset
opkg install /tmp/swanpan-chnroute_*.ipk
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
