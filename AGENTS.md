# Repository Guidelines

## Project Structure & Module Organization

This repository is an OpenWrt 25.12 package feed. Each top-level `swanpan-*` directory is one package:

- `swanpan-usb-wan-name/` installs a network hotplug script.
- `swanpan-chnroute/` installs the route-data manager, init script, and bundled CIDR data.
- `swanpan-chinadns-ng/` installs a verified target-specific binary, configuration, and procd service.
- `swanpan-mwan3-patch/` adds source-ipset matching to mwan3.
- `swanpan-luci-app-mwan3-patch/` adds its field to versioned LuCI views.

Metadata and install rules live in each package's `Makefile`; target files live under `files/`. `scripts/build-sdk.sh` runs container builds, and ignored `dist/` holds their artifacts. General instructions belong in `README.md`; there is no test directory.

## Build, Test, and Development Commands

For a containerized build, set the release, matching SDK image, and packages:

```sh
OPENWRT_VERSION=25.12.2 \
SDK_IMAGE=openwrt/sdk:mediatek-filogic-25.12.2 \
PACKAGES='swanpan-chinadns-ng swanpan-mwan3-patch' \
OUTPUT_DIR=dist/25.12.2/mediatek-filogic \
./scripts/build-sdk.sh
```

For a manual SDK build, add this repository as a local feed and run:

```sh
./scripts/feeds update swanpan
./scripts/feeds install -a -p swanpan
make defconfig
make package/feeds/swanpan/swanpan-chnroute/compile V=s
```

Replace the final package name as needed. Container artifacts go to `OUTPUT_DIR`; manual artifacts go to `bin/packages/<architecture>/swanpan/`. Run `make package/index` only for a feed index. Syntax-check changed shell files with `sh -n` and ShellCheck.

## Coding Style & Naming Conventions

Follow OpenWrt package conventions: uppercase package variables, tab-indented recipe commands, and `define Package/...` blocks. Shell files target `/bin/sh`; BusyBox `ash` extensions must be documented with narrow ShellCheck suppressions. Use tabs for shell block indentation, `snake_case` function names, and uppercase constants such as `STATE_DIR`. Quote expansions and fail explicitly on unsafe states.

## Testing Guidelines

No tests or coverage threshold exist. At minimum, syntax-check every changed shell file and compile every affected package in a matching SDK. For service or hotplug changes, also install the generated APK on a test router and verify init/procd behavior, logs, and upgrade preservation of declared configuration files.

## Commit & Pull Request Guidelines

Use Conventional Commit subjects, for example: `feat(feed): add initial OpenWrt 25.12 packages`. Add a body explaining behavior and packaging consequences. Pull requests should describe affected packages, target architecture, validation commands, and device testing. Link relevant issues and include logs for runtime changes; screenshots are only useful for UI-facing changes.

## Security & Source Updates

Never replace pinned commits or release assets with floating URLs. When updating upstream content, update the package version, source or release identifier, and SHA-256 together. Do not bypass download verification or commit generated APK artifacts.
