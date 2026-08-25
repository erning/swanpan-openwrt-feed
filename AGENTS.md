# Repository Guidelines

## Project Structure & Module Organization

This repository is an OpenWrt 25.12 package feed. Each top-level `swanpan-*` directory is one package:

- `swanpan-usb-wan-name/` installs a network hotplug script.
- `swanpan-chnroute/` installs the route-data manager, init script, and bundled CIDR data.
- `swanpan-chinadns-ng/` installs a verified binary, configuration, and procd service.
- `swanpan-mwan3-patch/` adds source-ipset matching to mwan3.
- `swanpan-luci-app-mwan3-patch/` adds its field to versioned LuCI views.

Package rules live in each `Makefile`; target files live under `files/`. `justfile` defines device builds, `scripts/build-sdk.sh` runs them, ignored `dist/` holds artifacts and caches, and `tests/` contains integration tests.

## Build, Test, and Development Commands

Run `just` to list device targets. Build one with its default OpenWrt version or pass an explicit version:

```sh
just MT3000
just MT3000 25.12.2
just ALL
```

For a custom or manual SDK build, add this repository as a local feed and run:

```sh
./scripts/feeds update swanpan
./scripts/feeds install -a -p swanpan
make defconfig
make package/feeds/swanpan/swanpan-chnroute/compile V=s
```

Replace the package name as needed. Container artifacts go to `OUTPUT_DIR`; manual artifacts go to `bin/packages/<architecture>/swanpan/`. Run `make package/index` only for a feed index. Validate cache changes with `tests/test-build-sdk-cache.sh`; check other shell files with `sh -n` and ShellCheck.

## Coding Style & Naming Conventions

Follow OpenWrt package conventions: uppercase package variables, tab-indented recipe commands, and `define Package/...` blocks. Shell files target `/bin/sh`; BusyBox `ash` extensions must be documented with narrow ShellCheck suppressions. Use tabs for shell block indentation, `snake_case` function names, and uppercase constants such as `STATE_DIR`. Quote expansions and fail explicitly on unsafe states.

## Scope and Simplicity

This is a personal feed for a known set of devices. Build the simplest thing that satisfies the actual requirement, and before adding a mechanism check whether dropping a requirement removes the need for it.

Packages that modify files owned by another package (`swanpan-mwan3-patch`, `swanpan-luci-app-mwan3-patch`) follow these rules:

- Modify a stock upstream file only. When the target already carries this feed's changes, report that and leave it alone.
- Do not write migration code that upgrades one release of our own output to another. Removal restores the backup, so remove-and-reinstall is the supported way to re-apply after this feed changes.
- Detect the target by content, not by a version map or a feature marker: apply candidates to a temporary copy and let the first clean match win.
- Ship one patch file per upstream variant, with context trimmed to the minimum that still locates each hunk, so one file covers several upstream revisions.
- Build the result in a temporary copy and install it with a rename, so the target is never left half-written.

## Testing Guidelines

There is no coverage threshold. Run `tests/test-build-sdk-cache.sh` for cache changes. Syntax-check every changed shell file and compile affected packages in a matching SDK. For service or hotplug changes, install the APK on a test router and verify procd behavior, logs, and configuration preservation.

## Commit & Pull Request Guidelines

Use Conventional Commit subjects, for example: `feat(feed): add initial OpenWrt 25.12 packages`. Add a body explaining behavior and packaging consequences. Pull requests should describe affected packages, target architecture, validation commands, and device testing. Link relevant issues and include logs for runtime changes; screenshots are only useful for UI-facing changes.

## Security & Source Updates

Never replace pinned commits or release assets with floating URLs. When updating upstream content, update the package version, source or release identifier, and SHA-256 together. Do not bypass download verification or commit generated APK artifacts.
