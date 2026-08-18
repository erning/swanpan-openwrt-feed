# Swanpan OpenWrt Feed

本仓库提供 Swanpan 维护的 OpenWrt 软件包。当前面向使用 APK 包管理器的 OpenWrt
25.12，并按目标架构提供预编译的 ChinaDNS-NG。

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

使用与目标设备版本、target 和 subtarget 一致的 OpenWrt SDK。根据需要分别构建软件包：

```sh
make defconfig
make package/feeds/swanpan/swanpan-usb-wan-name/compile V=s
make package/feeds/swanpan/swanpan-chnroute/compile V=s
make package/feeds/swanpan/swanpan-chinadns-ng/compile V=s
make package/feeds/swanpan/swanpan-mwan3-patch/compile V=s
make package/feeds/swanpan/swanpan-luci-app-mwan3-patch/compile V=s
```

生成的 `.apk` 位于：

```text
bin/packages/<architecture>/swanpan/
```

如果需要生成可作为软件源使用的索引，再执行：

```sh
make package/index
```

## 安装

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
