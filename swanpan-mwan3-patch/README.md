# swanpan-mwan3-patch

`swanpan-mwan3-patch` adds the UCI rule options `ipset_src` and
`ipset_src_local` to `mwan3`.
It patches `/lib/mwan3/mwan3.sh` on-device at install time (no need to rebuild `mwan3`).

Router-originated traffic uses a dedicated `mwan3_output_hook` and
`mwan3_rules_output` chain. Forwarded traffic keeps using `mwan3_hook` and
`mwan3_rules`, so enabling `ipset_src_local` never weakens the source-IPset
check for forwarded packets.

## What it adds

In `config rule` sections in `/etc/config/mwan3`, you can use:

- `option ipset <setname>`: existing behavior (match destination via ipset)
- `option ipset_src <setname>`: new behavior (match source via ipset)
- `option ipset_src_local '1'`: let router-originated traffic match the rule
  without requiring its source address to be present in `ipset_src`

Internally this becomes:

- `ipset`     -> `-m set --match-set <setname> dst`
- `ipset_src` -> `-m set --match-set <setname> src`

Both matches are applied to the optional LOG rule and the main MARK/policy rule.
The current OpenWrt 25.12 implementation builds separate, order-preserving
`mwan3_rules` and `mwan3_rules_output` chains. When `ipset_src_local` is enabled,
only the output-chain copy omits the source-ipset and input-interface conditions;
the forwarding-chain copy remains restricted by `ipset_src`. The output copy
retains the rule's protocol, source/destination address, destination ipset, port,
mark, and policy conditions. The option has no effect unless `ipset_src` is also
configured.

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
	option ipset_src_local '1'
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

Patch selection is content-based (apply to a temporary copy), not a hardcoded
version map. The package first selects a source-ipset patch from `patches/`,
then selects a local-traffic patch from `patches-local/` against the staged
result. The two directories use corresponding variants. For convenience, below
is the tested mapping from upstream `openwrt/packages` `PKG_VERSION` (starting
at `2.8.0`) to the first matching variant pair.

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

1. If `/lib/mwan3/mwan3.sh` already contains both `ipset_src_local` and
   `mwan3_rules_output`, it exits successfully (idempotent).
2. If it detects an earlier `ipset_src` or `ipset_src_local` implementation, it
   restores the pristine backup before continuing.
3. It iterates patches under
   `/usr/share/swanpan-mwan3-patch/patches/*.patch` in glob order, applying each
   candidate to a temporary copy. The first source-ipset patch that applies is
   selected.
4. It stages that result and selects a compatible second patch from
   `/usr/share/swanpan-mwan3-patch/patches-local/*.patch` in the same way.

   If multiple patches would apply cleanly (rare, but possible if patches
   overlap), the first match in glob order wins. Use names such as
   `00-<name>.patch` and `10-<name>.patch` to control precedence.

5. It backs up the current unpatched file:

   - `/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch`

6. It applies both selected patches. If either fails, it restores the backup.
7. On a live system (no `IPKG_INSTROOT`), it restarts mwan3.

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

2) Create a source-ipset patch and its corresponding local-traffic patch.

The patch should be a unified diff that targets `lib/mwan3/mwan3.sh` (relative path), e.g.:

```diff
--- lib/mwan3/mwan3.sh
+++ lib/mwan3/mwan3.sh
@@ ...
```

3) Put the patch files here:

- `swanpan-mwan3-patch/files/usr/share/swanpan-mwan3-patch/patches/<name>.patch`
- `swanpan-mwan3-patch/files/usr/share/swanpan-mwan3-patch/patches-local/<name>-local.patch`

Naming is not semantically important for correctness because selection happens
against a temporary copy, but it matters for readability and precedence.

Use something recognizable:

- `00-mwan3-2.12.0.patch`
- `10-openwrt-25.12-<date>.patch`
- `20-variant-<sha256-prefix>.patch`

If you only have a single patch file, the name is purely cosmetic.

4) Test selection locally (simulated root):

- Create a temp root containing `lib/mwan3/mwan3.sh` and copy both patch sets
  into their respective directories under `usr/share/swanpan-mwan3-patch/`
- Run the extracted `postinst` with `IPKG_INSTROOT` set

The install should print which patch pair was chosen and result in a patched
`mwan3.sh` containing both `ipset_src` and `ipset_src_local`.

## Troubleshooting

- Install fails with `no compatible source-IPset patch found` or
  `no compatible local-traffic patch found`:
  - Check the printed `sha256` of `/lib/mwan3/mwan3.sh`
  - Add a new patch variant as described above

- `ipset_src` seems to have no effect:
  - Confirm your ipset exists and contains the expected IPs: `ipset list <setname>`
  - Confirm mwan3 rules were regenerated: `/etc/init.d/mwan3 restart`
  - Confirm your traffic matches the rule (family/proto/src/dest)

- Router-originated traffic still does not match:
  - Confirm the rule has both `ipset_src` and `ipset_src_local '1'`
  - Confirm `OUTPUT` jumps to `mwan3_output_hook`
  - Confirm the matching rule appears without the source ipset in
    `iptables -t mangle -S mwan3_rules_output`
  - Confirm the forwarding copy still contains the source ipset in
    `iptables -t mangle -S mwan3_rules`
