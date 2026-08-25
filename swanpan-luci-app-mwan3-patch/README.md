# swanpan-luci-app-mwan3-patch

`swanpan-luci-app-mwan3-patch` is an overlay package that adds the LuCI rule
options `ipset_src` and `ipset_src_local` to `luci-app-mwan3`.

It replaces the installed LuCI view on-device at install time, without rebuilding
`luci-app-mwan3`. This is necessary for modern releases because OpenWrt installs
a `jsmin`-processed `rule.js`, so a source patch cannot be applied reliably on
the router.

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
  - `/www/luci-static/resources/view/mwan3/network/rule.js.gz` (kept in sync when present)

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
- `/usr/share/swanpan-luci-app-mwan3-patch/overlays/<version>/stock.sha256` (accepted upstream fingerprints)

The directory name identifies the upstream target-file revision for maintainers;
it is not used as a runtime version range. LuCI package versions can advance due
to unrelated changes while a release branch keeps an older `rule.js`, so version
ordering cannot select an overlay safely.

The installer instead hashes the installed target and requires an exact match in
one `stock.sha256`. For modern JS, the manifest contains fingerprints for both
the upstream source and the output produced by that LuCI revision's `jsmin`.
This supports official minified packages as well as unminified development
builds without accepting unknown content.

The checked-in fingerprints and overlays are tested against every available
OpenWrt 21.02, 22.03, 23.05, 24.10, and 25.12 release and release-candidate tag
in the local OpenWrt mirrors.

At install time it:

1. Verifies that an existing `rule.js.gz` decompresses to the installed
   `rule.js`. If not, installation stops without changing either file.
2. Checks whether any shipped overlay is already installed. If so, it reports
   that state and leaves both the target and its backup unchanged.
3. Matches the exact SHA-256 of a known stock target. Unknown or locally modified
   content is left untouched and installation fails.
4. Stages the overlay, backup, and any gzip counterpart before installing each
   completed file with a rename.

The backup paths are:

- `/www/luci-static/resources/view/mwan3/network/rule.js.orig.swanpan-luci-app-mwan3-patch`
- `/www/luci-static/resources/view/mwan3/network/rule.js.gz.orig.swanpan-luci-app-mwan3-patch` (if present)

The legacy backup is
`/usr/lib/lua/luci/model/cbi/mwan/ruleconfig.lua.orig.swanpan-luci-app-mwan3-patch`.
If `rule.js.gz` exists, `gzip` is required and a synchronized compressed overlay
is installed. If it does not exist, the package does not create one.

Important: reinstalling or upgrading `luci-app-mwan3` may overwrite
`/www/.../rule.js` again. In that case, reinstall this overlay package to
re-apply.
The installer refreshes its backup only after the new target matches a known
stock fingerprint, so later removal restores the current upstream version.

The package deliberately does not migrate an overlay written by an older release
of itself. Remove and reinstall it when this feed changes an overlay; removal
restores stock content before the new package applies.

On removal (`postrm`), it restores the backup file(s) if present.

## Adding support for a new upstream version

You need a new overlay and stock fingerprint whenever the upstream target file
changes.

Recommended workflow:

1. Identify the LuCI Git ref pinned by the OpenWrt release. An installed package
   version containing a seven-character commit hash can also be used:

```sh
apk list --installed luci-app-mwan3
```

2. Generate the corresponding overlay and `stock.sha256` under:

- `swanpan-luci-app-mwan3-patch/files/usr/share/swanpan-luci-app-mwan3-patch/overlays/<base-version>/rule.js`

The directory name is derived from the commit that last changed the target file,
not from the whole LuCI feed's HEAD.

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

The generator auto-detects whether the target LuCI version uses modern JS
(`rule.js`) or legacy Lua CBI (`ruleconfig.lua`). It applies the first clean
patch variant, reuses a byte-identical overlay when possible, and records the
stock source fingerprint. For JS it also builds that revision's `jsmin` and
records the fingerprint of the installed minified form.

### Generate an overlay for a specific installed luci-app-mwan3 version

If the device reports:

```sh
apk list --installed luci-app-mwan3
```

You can pass that value directly:

```sh
swanpan-luci-app-mwan3-patch/tools/gen-overlay.sh 26.052.56300~90d5914-r1
```

The script will extract the embedded commit hash and regenerate the matching
overlay directory.

## Troubleshooting

- Install fails with `target file not found`:
  - Ensure `luci-app-mwan3` is installed and provides `/www/luci-static/resources/view/mwan3/network/rule.js`

- Install fails with `unsupported or modified rule.js` (or `ruleconfig.lua`):
  - Compare the reported SHA-256 with the checked-in `stock.sha256` files
  - If it is a new stock upstream variant, run `tools/gen-overlay.sh` for the
    pinned LuCI ref and test it before rebuilding the package
  - If it is locally modified, restore the stock `luci-app-mwan3` file first

- Install fails because `rule.js.gz` does not contain `rule.js`:
  - Reinstall `luci-app-mwan3` so its plain and compressed assets agree, then
    install this package again

- The added fields are not shown:
  - Ensure the overlay package is installed: `apk info swanpan-luci-app-mwan3-patch`
  - Force refresh the browser cache (or hard reload)
  - Check the installed JS contains `ipset_src_local`:

    ```sh
    grep -n "ipset_src_local" /www/luci-static/resources/view/mwan3/network/rule.js
    ```
