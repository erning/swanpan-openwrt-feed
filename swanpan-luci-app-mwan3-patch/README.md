# swanpan-luci-app-mwan3-patch

`swanpan-luci-app-mwan3-patch` is an overlay package that adds the LuCI rule
options `ipset_src` and `ipset_src_local` to `luci-app-mwan3`.

It replaces the installed LuCI JS view on-device at install time (no need to rebuild `luci-app-mwan3`).

## What it adds

In `/etc/config/mwan3` rule sections, `mwan3` supports:

- `option ipset <setname>`: match destination via ipset (existing)
- `option ipset_src <setname>`: match source via ipset (added by `swanpan-mwan3-patch`)
- `option ipset_src_local '1'`: allow router-originated traffic to use the rule
  without matching `ipset_src`, while forwarded traffic remains restricted

This overlay package exposes both fields in the LuCI rules UI.

## Files touched

- Source file in LuCI repo (used to generate overlays):
  - `applications/luci-app-mwan3/htdocs/luci-static/resources/view/mwan3/network/rule.js`
- Legacy LuCI (Lua CBI) source file in LuCI repo:
  - `applications/luci-app-mwan3/luasrc/model/cbi/mwan/ruleconfig.lua`
- Installed files on device (replaced):
  - `/www/luci-static/resources/view/mwan3/network/rule.js`
  - `/www/luci-static/resources/view/mwan3/network/rule.js.gz` (kept in sync when `gzip` exists)

Legacy LuCI (Lua CBI) installed file (replaced):

- `/usr/lib/lua/luci/model/cbi/mwan/ruleconfig.lua`

This package replaces the installed file(s) depending on which LuCI variant is present.

## Usage

### 1) Install

Build it from an OpenWrt SDK with the Swanpan feed installed:

```sh
make package/feeds/swanpan/swanpan-luci-app-mwan3-patch/compile V=s
```

Install it from a configured feed with `apk add swanpan-luci-app-mwan3-patch`,
or install both generated files directly:

```sh
apk add --allow-untrusted \
  /tmp/swanpan-mwan3-patch-*.apk \
  /tmp/swanpan-luci-app-mwan3-patch-*.apk
```

Remove the former `luci-app-mwan3-src-ipset` and `mwan3-src-ipset` packages
before installing these renamed packages, allowing their removal scripts to
restore the upstream files first.

This package depends on `luci-app-mwan3` and `swanpan-mwan3-patch`.

### 2) Configure in LuCI

After installing, go to:

- Network → MultiWAN Manager → Rules

You should see these fields:

- `IPset source` (`ipset_src`)
- `Allow router-originated traffic` (`ipset_src_local`)

It is populated from the output of:

- `/usr/libexec/luci-mwan3 ipset dump`

### 3) Example UCI rule

Example `/etc/config/mwan3` rule using `ipset_src`:

```uci
config rule 'src_example'
	option family 'ipv4'
	option proto 'all'
	option use_policy 'wan'
	option ipset_src 'my_src_set'
	option ipset_src_local '1'
	option logging '1'
```

Apply/restart:

```sh
/etc/init.d/mwan3 restart
```

## Supported versions

This package ships multiple pre-generated overlays under:

- `/usr/share/swanpan-luci-app-mwan3-patch/overlays/<version>/rule.js` (modern JS LuCI)
- `/usr/share/swanpan-luci-app-mwan3-patch/overlays/<version>/ruleconfig.lua` (legacy Lua CBI LuCI)

It reads the installed `luci-app-mwan3` version from APK, with an opkg fallback
for older systems. It then selects the newest compatible overlay whose LuCI era
is not newer than the installed package.

Example:

- Installed: `26.052.56300~90d5914-r1`
- Selected overlay: `26.052.56300~90d5914`

At install time it:

1. Backs up the original file(s):
   - `/www/luci-static/resources/view/mwan3/network/rule.js.orig.swanpan-luci-app-mwan3-patch`
   - `/www/luci-static/resources/view/mwan3/network/rule.js.gz.orig.swanpan-luci-app-mwan3-patch` (if present)
2. Copies the selected overlay file into the correct LuCI target:
   - modern JS: `/www/.../rule.js`
   - legacy Lua CBI: `/usr/lib/lua/.../ruleconfig.lua`
3. For modern JS LuCI only: rebuilds `/www/.../rule.js.gz` from the new content when `gzip` exists and the `.gz` file is present

Important: reinstalling or upgrading `luci-app-mwan3` may overwrite `/www/.../rule.js` again. In that case, reinstall this overlay package to re-apply.
The installer refreshes its backup when it detects an unpatched upstream file,
so later removal restores the current upstream version.

On removal (`postrm`), it restores the backup file(s) if present.

## Adding support for a new upstream version

You need a new overlay when the upstream `rule.js` changes.

Recommended workflow:

1) Identify the installed `luci-app-mwan3` version on the target device:

```sh
apk list --installed luci-app-mwan3
```

2) Generate a corresponding overlay under:

- `swanpan-luci-app-mwan3-patch/files/usr/share/swanpan-luci-app-mwan3-patch/overlays/<base-version>/rule.js`

The directory name is the LuCI version that introduced that overlay content,
without the trailing package release.

### Generate an overlay from the local LuCI mirror

This repo uses a local mirror:

- `~/projects/mirrors/openwrt-luci.git`

The overlay generator applies a patch template:

- modern JS: `swanpan-luci-app-mwan3-patch/tools/patches/00-ipset_src.patch`
- legacy Lua CBI: `swanpan-luci-app-mwan3-patch/tools/patches/10-legacy-ruleconfig-ipset_src.patch`

These templates intentionally do not live in a package-level `patches/`
directory, which OpenWrt would process during `Build/Prepare`.

Generate overlays with:

```sh
swanpan-luci-app-mwan3-patch/tools/gen-overlay.sh openwrt-25.12
```

The generator auto-detects whether the target LuCI version uses modern JS (`rule.js`) or legacy Lua CBI (`ruleconfig.lua`) and writes the correct overlay filename into the version directory.

### Generate an overlay for a specific installed luci-app-mwan3 version

If the device reports:

```sh
apk list --installed luci-app-mwan3
```

You can pass that value directly:

```sh
swanpan-luci-app-mwan3-patch/tools/gen-overlay.sh 26.052.56300~90d5914-r1
```

The script will extract the embedded commit hash and regenerate the matching overlay directory.

## Troubleshooting

- Install fails with `target file not found`:
  - Ensure `luci-app-mwan3` is installed and provides `/www/luci-static/resources/view/mwan3/network/rule.js`

- Install fails with `no overlay found`:
  - Check the device `luci-app-mwan3` version and generate a matching overlay directory

- The added fields are not shown:
  - Ensure the overlay package is installed: `apk info swanpan-luci-app-mwan3-patch`
  - Force refresh the browser cache (or hard reload)
  - Check the installed JS contains `ipset_src_local`:

    ```sh
    grep -n "ipset_src_local" /www/luci-static/resources/view/mwan3/network/rule.js
    ```
