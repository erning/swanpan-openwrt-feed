# Repository Guidelines

## Project Structure & Module Organization

This repository is an OpenWrt 25.12 package feed. Each top-level `swanpan-*` directory is one package:

- `swanpan-usb-wan-name/` installs a network hotplug script.
- `swanpan-chnroute/` installs the route-data manager, init script, and bundled CIDR data.
- `swanpan-chinadns-ng/` installs a verified target-specific binary, configuration, and procd service.
- `swanpan-mwan3-patch/` adds source-ipset matching to mwan3.
- `swanpan-luci-app-mwan3-patch/` adds its field to versioned LuCI views.

Package metadata and install rules live in each package's `Makefile`; files copied to the target root filesystem live under `files/`. General setup and installation instructions belong in `README.md`. There is currently no separate test or asset directory.

## Build, Test, and Development Commands

Work from an OpenWrt SDK matching the target release, target, and subtarget. Add this repository as a local feed, then run:

```sh
./scripts/feeds update swanpan
./scripts/feeds install -a -p swanpan
make defconfig
make package/feeds/swanpan/swanpan-chnroute/compile V=s
```

Replace the final package name to build another package. Artifacts are written to `bin/packages/<architecture>/swanpan/`. Run `make package/index` only when a distributable feed index is needed. For fast validation, run `sh -n swanpan-chnroute/files/chnroute` and ShellCheck on each changed shell script.

## Coding Style & Naming Conventions

Follow OpenWrt package conventions: uppercase package variables, tab-indented recipe commands, and `define Package/...` blocks. Shell files target `/bin/sh`; BusyBox `ash` extensions must be documented with narrow ShellCheck suppressions. Use tabs for shell block indentation, `snake_case` function names, and uppercase constants such as `STATE_DIR`. Quote expansions and fail explicitly on unsafe states.

## Testing Guidelines

There is no automated test framework or coverage threshold. At minimum, syntax-check every changed shell file and compile every affected package in a matching SDK. For service or hotplug changes, also install the generated APK on a test router and verify init/procd behavior, logs, and upgrade preservation of declared configuration files.

## Commit & Pull Request Guidelines

Use concise Conventional Commit subjects, following the existing pattern: `feat(feed): add initial OpenWrt 25.12 packages`. Add a useful body explaining behavior and packaging consequences. Pull requests should describe affected packages, target architecture, validation commands, and device testing. Link relevant issues and include logs for runtime changes; screenshots are only useful for UI-facing changes.

## Security & Source Updates

Never replace pinned commits or release assets with floating URLs. When updating upstream content, update the package version, source or release identifier, and SHA-256 together. Do not bypass download verification or commit generated APK artifacts.
