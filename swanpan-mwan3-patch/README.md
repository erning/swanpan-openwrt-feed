# swanpan-mwan3-patch

`swanpan-mwan3-patch` adds a new UCI rule option `ipset_src` to `mwan3`.
It patches `/lib/mwan3/mwan3.sh` on-device at install time (no need to rebuild `mwan3`).

## What it adds

In `config rule` sections in `/etc/config/mwan3`, you can use:

- `option ipset <setname>`: existing behavior (match destination via ipset)
- `option ipset_src <setname>`: new behavior (match source via ipset)

Internally this becomes:

- `ipset`     -> `-m set --match-set <setname> dst`
- `ipset_src` -> `-m set --match-set <setname> src`

Both matches are applied to the optional LOG rule and the main MARK/policy rule.

## Usage

### 1) Install

Build it from an OpenWrt SDK with the Swanpan feed installed:

```sh
make package/feeds/swanpan/swanpan-mwan3-patch/compile V=s
```

Install it from a configured feed with `apk add swanpan-mwan3-patch`, or install
the generated file with
`apk add --allow-untrusted /tmp/swanpan-mwan3-patch-*.apk`.

If `mwan3-src-ipset` is already installed, remove it before installing this
renamed package so its removal script can restore the original mwan3 file.

This package depends on `mwan3` and `patch`.

### 2) Create your ipset

This package does not create or manage ipsets for you. You must create the ipset used by `ipset_src`.

Example (IPv4):

```sh
ipset create my_src_set hash:ip -exist
ipset add my_src_set 192.0.2.10 -exist
```

### 3) Configure mwan3 rule

Example `/etc/config/mwan3` rule:

```uci
config rule 'src_example'
	option family 'ipv4'
	option proto 'all'
	option use_policy 'wan'
	option ipset_src 'my_src_set'
	option logging '1'
```

Apply/restart:

```sh
/etc/init.d/mwan3 restart
```

## Supported versions

This package does NOT hardcode a `mwan3` version → patch mapping.
Instead, it selects a patch based on whether it can be applied cleanly to the installed `/lib/mwan3/mwan3.sh`.

Important: patch filenames are NOT semantic. For example, `00-ipset_src.patch` is just the current patch variant name; it is not limited to any specific `mwan3` version.

As of 2026-01-15, the patch set was validated against `openwrt/packages` branches starting from `openwrt-22.03`:

- `origin/openwrt-22.03`
- `origin/openwrt-23.05`
- `origin/openwrt-24.10`
- `origin/openwrt-25.12`
- `origin/master`

This includes historical `mwan3.sh` variants (2022+) and also covers later `PKG_VERSION` bumps where `mwan3.sh` did not change.

In practice, this means you usually only need a small number of patch files. If multiple upstream `mwan3` versions ship the same `mwan3.sh`, they will all use the same patch variant.

If your device ships a different `mwan3.sh` variant, installation will fail with a message that includes the detected `mwan3` version (if available) and the `sha256` of `/lib/mwan3/mwan3.sh`.

Note: patch selection runs `patch` commands during installation. The package
depends on GNU patch; if needed, install it with `apk add patch`.

## Patch variants shipped

Patch selection is content-based (`patch` dry-run), not a hardcoded version map.
Still, for convenience, below is the tested mapping from upstream `openwrt/packages` `PKG_VERSION` (starting at `2.8.0`) to the first matching patch variant.

- `00-ipset_src.patch`: `2.10.0+`
- `10-legacy-60b05beed3da.patch`: `2.8.0` .. `2.8.6`
- `10-legacy-b300474e3953.patch`: `2.8.7` .. `2.8.8`
- `10-legacy-50c29cbe5312.patch`: `2.8.9` .. `2.8.12`
- `10-legacy-429d857ed5ab.patch`: `2.9.0`

If you're using a vendor fork (e.g. GL.iNet), your `mwan3` `Version:` may not exist upstream.
As long as your `/lib/mwan3/mwan3.sh` matches one of the supported variants, one of the patches above will still apply.

## Patch selection strategy (how it works)

Implementation lives in `swanpan-mwan3-patch/files/usr/libexec/swanpan-mwan3-patch/postinst.sh`.

At install time:

1. If `/lib/mwan3/mwan3.sh` already contains `ipset_src`, it exits successfully (idempotent).
2. Otherwise it iterates all patch files under `/usr/share/swanpan-mwan3-patch/patches/*.patch` (glob order).
3. For each patch, it runs:

   - `patch --dry-run --forward -p0 < patchfile`

   The first patch that dry-runs cleanly is selected.

If multiple patches would apply cleanly (rare, but possible if patches overlap), the first match in glob order wins. If you ever need multiple variants, prefer naming like `00-<name>.patch`, `10-<name>.patch` to control precedence.

4. It backs up the current unpatched file:

   - `/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch`

5. It applies the patch with `patch --batch --forward -p0`.
6. On a live system (no `IPKG_INSTROOT`), it restarts mwan3.

If a mwan3 upgrade replaces the target, reinstalling this package refreshes the
backup before applying the patch again. On removal (`postrm`), it restores the
backup file if present and restarts mwan3.

## Adding a new patch variant

You only need a new patch when upstream changes `net/mwan3/files/lib/mwan3/mwan3.sh` in a way that breaks patch context.

Recommended workflow:

1) Obtain the target `mwan3.sh` (the exact file you need to support):

- From device:

  ```sh
  scp root@router:/lib/mwan3/mwan3.sh ./mwan3.sh.target
  ```

- Or from `openwrt/packages`:

  ```sh
  git -C ~/projects/openwrt/packages show <ref>:net/mwan3/files/lib/mwan3/mwan3.sh > mwan3.sh.target
  ```

2) Create a patch that adds `ipset_src` support.

The patch should be a unified diff that targets `lib/mwan3/mwan3.sh` (relative path), e.g.:

```diff
--- lib/mwan3/mwan3.sh
+++ lib/mwan3/mwan3.sh
@@ ...
```

3) Put the patch file here:

- `swanpan-mwan3-patch/files/usr/share/swanpan-mwan3-patch/patches/<name>.patch`

Naming is not semantically important for correctness (selection is via `patch --dry-run`), but it matters for readability and (if you ever have multiple variants) precedence.

Use something recognizable:

- `00-mwan3-2.12.0.patch`
- `10-openwrt-25.12-<date>.patch`
- `20-variant-<sha256-prefix>.patch`

If you only have a single patch file, the name is purely cosmetic.

4) Test selection locally (simulated root):

- Create a temp root containing `lib/mwan3/mwan3.sh` and copy patches into `usr/share/swanpan-mwan3-patch/patches/`
- Run the extracted `postinst` with `IPKG_INSTROOT` set

The install should print which patch was chosen and result in a patched `mwan3.sh` containing `ipset_src`.

## Troubleshooting

- Install fails with `no compatible patch found`:
  - Check the printed `sha256` of `/lib/mwan3/mwan3.sh`
  - Add a new patch variant as described above

- `ipset_src` seems to have no effect:
  - Confirm your ipset exists and contains the expected IPs: `ipset list <setname>`
  - Confirm mwan3 rules were regenerated: `/etc/init.d/mwan3 restart`
  - Confirm your traffic matches the rule (family/proto/src/dest)
