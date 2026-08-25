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

Which rules get a router-originated copy differs between the patch variants. The
25.12 variant copies every rule into `mwan3_rules_output` except one bound to
`src_iface` without `ipset_src_local`: that chain is reached from `OUTPUT`, where
a packet has no ingress device, so an `-i` match could never hit. The legacy
variants instead prepend a `! -i +` copy of the rule to `mwan3_rules`, and only
for rules that set `ipset_src_local`; every other rule keeps upstream's handling
of router-originated traffic.

When `ipset_src_local` and `sticky` are both enabled, sticky selection applies
only to forwarded traffic. Router-originated traffic jumps directly to the
configured policy chain, so a shared router source address cannot pin local
connections to a sticky member; conntrack marks still keep each established
connection on one interface. Every shipped patch variant implements this,
including the legacy ones. Rules that leave `ipset_src_local` unset keep
upstream behavior and stay on the sticky chain.

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

This package only patches a stock `mwan3.sh`. If `/lib/mwan3/mwan3.sh` is
already patched it says so and leaves the file alone, so picking up a newer
patch release means removing the package first:

```sh
apk del swanpan-mwan3-patch && apk add swanpan-mwan3-patch
```

Removal restores `/lib/mwan3/mwan3.sh` from the backup, so the reinstall starts
from a pristine file. The same applies after upgrading `mwan3` itself.

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

As of 2026-08-25, the patch set was validated against `openwrt/packages` branches starting from `openwrt-21.02`:

- `origin/openwrt-21.02`
- `origin/openwrt-22.03`
- `origin/openwrt-23.05`
- `origin/openwrt-24.10`
- `origin/openwrt-25.12`
- `origin/master`

This includes historical `mwan3.sh` variants (2022+) and also covers later `PKG_VERSION` bumps where `mwan3.sh` did not change.

In practice, this means you usually only need a small number of patch files. If multiple upstream `mwan3` versions ship the same `mwan3.sh`, they will all use the same patch variant.

If your device ships a different `mwan3.sh` variant, installation will fail with
a message carrying the `sha256` of `/lib/mwan3/mwan3.sh`, which is also how the
legacy patch files are named.

Note: patch selection runs `patch` commands during installation. The package
depends on GNU patch; if needed, install it with `apk add patch`.

## Patch variants shipped

Patch selection is content-based (apply to a temporary copy), not a hardcoded
version map. Each file under `patches/` holds two unified-diff sections against
`lib/mwan3/mwan3.sh` — source-ipset support, then local-traffic support — which
a single `patch` run applies in order. For convenience, below is the tested
mapping from upstream `openwrt/packages` `PKG_VERSION` (starting at `2.8.0`) to
the first matching variant.

- `00-ipset_src.patch`: `2.11.0+`
- `10-legacy-5cf615912c17.patch`: `2.10.0` .. `2.10.13`
- `10-legacy-60b05beed3da.patch`: `2.8.0` .. `2.8.6`
- `10-legacy-b300474e3953.patch`: `2.8.7` .. `2.8.8`
- `10-legacy-50c29cbe5312.patch`: `2.8.9` .. `2.8.12`
- `10-legacy-429d857ed5ab.patch`: `2.9.0`

If you're using a vendor fork (e.g. GL.iNet), your `mwan3` `Version:` may not exist upstream.
As long as your `/lib/mwan3/mwan3.sh` matches one of the supported variants, one of the patches above will still apply.

## Design constraints

The installer is deliberately small. These constraints are what keep it that
way, and changes should preserve them:

- It patches a stock `mwan3.sh` only. A file that already contains `ipset_src`
  is reported and left untouched.
- It never migrates content an earlier release of this package produced. Nothing
  in a patched file records which release wrote it, and inferring that from
  feature markers is what shipped release 4's sticky fix as a silent no-op.
  Remove and reinstall instead.
- Variant detection is content-based. There is no `mwan3` version map and no
  apk/opkg version probing; the `sha256` in the failure message is the only
  identifier needed, and it is how the legacy patch files are named.
- One patch file per upstream variant, source-ipset section first, with narrow
  context so a single file covers several upstream revisions.

## Patch selection strategy (how it works)

Implementation lives in `swanpan-mwan3-patch/files/usr/libexec/swanpan-mwan3-patch/postinst.sh`.

At install time:

1. If `/lib/mwan3/mwan3.sh` already contains `ipset_src`, it reports that and
   exits successfully without touching the file. Nothing in a patched file says
   which release wrote it, so it is never re-patched in place; remove the
   package and install it again instead.
2. It iterates `/usr/share/swanpan-mwan3-patch/patches/*.patch` in glob order,
   applying each candidate with `patch -p0` to a temporary copy of the installed
   file. The first patch that applies cleanly wins, and that temporary copy is
   the file that gets installed, so `/lib/mwan3/mwan3.sh` is never left
   half-patched.

   If multiple patches would apply cleanly (rare, but possible if patches
   overlap), the first match in glob order wins. Use names such as
   `00-<name>.patch` and `10-<name>.patch` to control precedence.

3. It copies the unpatched file to
   `/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch`.
4. It writes the result beside `/lib/mwan3/mwan3.sh` and renames it over the
   target, so an interrupted copy cannot truncate the file.
5. On a live system (no `IPKG_INSTROOT`), it restarts mwan3.

On removal (`postrm`), it restores the backup file if present and restarts
mwan3. After upgrading `mwan3` itself, remove and reinstall this package so the
patch is selected against the new file.

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

2) Create the patch.

Each section is a unified diff that targets `lib/mwan3/mwan3.sh` (relative path),
e.g.:

```diff
--- lib/mwan3/mwan3.sh
+++ lib/mwan3/mwan3.sh
@@ ...
```

Keep the source-ipset section first and the local-traffic section second in the
same file; `patch` applies them in order, and the second one's hunks are written
against the output of the first.

Trim leading and trailing context to the minimum that still locates each hunk.
The shipped patches cover several upstream `mwan3.sh` revisions each precisely
because their context is narrow.

3) Put the patch file here:

- `swanpan-mwan3-patch/files/usr/share/swanpan-mwan3-patch/patches/<name>.patch`

Naming is not semantically important for correctness because selection happens
against a temporary copy, but it matters for readability and precedence.

Use something recognizable:

- `00-mwan3-2.12.0.patch`
- `10-openwrt-25.12-<date>.patch`
- `20-variant-<sha256-prefix>.patch`

The shipped `10-legacy-<prefix>.patch` names use the first 12 hex characters of
the target `mwan3.sh` sha256. `tests/test-mwan3-local-source.sh` relies on that:
it recovers each of those files from the upstream mirror and runs the full
install against it, so keep the convention for new legacy variants.

If you only have a single patch file, the name is purely cosmetic.

4) Test selection locally (simulated root):

- Create a temp root containing `lib/mwan3/mwan3.sh` and copy the patches into
  `usr/share/swanpan-mwan3-patch/patches/`
- Run the extracted `postinst` with `IPKG_INSTROOT` set

The install should print which patch was chosen and result in a patched
`mwan3.sh` containing both `ipset_src` and `ipset_src_local`.

`tests/test-mwan3-local-source.sh` does this for every shipped variant against
an `openwrt/packages` mirror.

## Troubleshooting

- Install fails with `no compatible patch found`:
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
