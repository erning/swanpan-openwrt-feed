#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
PATCH_DIR="$REPO_ROOT/swanpan-mwan3-patch/files/usr/share/swanpan-mwan3-patch/patches"
LOCAL_PATCH_DIR="$REPO_ROOT/swanpan-mwan3-patch/files/usr/share/swanpan-mwan3-patch/patches-local"
BASE_PATCH_FILE="$PATCH_DIR/00-ipset_src.patch"
LOCAL_PATCH_FILE="$LOCAL_PATCH_DIR/00-ipset_src_local.patch"
POSTINST="$REPO_ROOT/swanpan-mwan3-patch/files/usr/libexec/swanpan-mwan3-patch/postinst.sh"
OVERLAY_ROOT="$REPO_ROOT/swanpan-luci-app-mwan3-patch/files/usr/share/swanpan-luci-app-mwan3-patch/overlays"
MWAN3_PATH="net/mwan3/files/lib/mwan3/mwan3.sh"
TEST_ROOT=$(mktemp -d)

cleanup() {
	rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

grep -Fq 'config_get ipset_src' "$BASE_PATCH_FILE"
# shellcheck disable=SC2016 # Match literal shell variables in the patch.
[ "$(grep -Fc '$ipset $ipset_src' "$BASE_PATCH_FILE")" -eq 2 ]

# Every local-traffic variant must carry the same option and the same sticky
# bypass. Release 4 shipped the bypass in the 25.12 variant only, so check all
# of them rather than the one the 25.12 tests below exercise.
for patch in "$LOCAL_PATCH_DIR"/*.patch; do
	grep -Fq 'config_get_bool ipset_src_local' "$patch"
	# shellcheck disable=SC2016 # Match literal shell variables in the patch.
	grep -Fq '[ "$ipset_src_local" -eq 1 ] && output_policy="$policy"' "$patch"
	# shellcheck disable=SC2016 # Match literal shell variables in the patch.
	grep -Fq -- '-j ${output_policy:-$policy}' "$patch"
	# No added rule may jump straight to $policy: that is the sticky wrapper
	# chain whenever the rule sets sticky and a named use_policy.
	# shellcheck disable=SC2016 # Match literal shell variables in the patch.
	[ "$(grep -c '^+.*-j \$policy' "$patch")" -eq 0 ]
done

grep -Fq 'mwan3_output_hook' "$LOCAL_PATCH_FILE"
grep -Fq 'mwan3_rules_output' "$LOCAL_PATCH_FILE"
[ "$(grep -Fc '! -i +' "$LOCAL_PATCH_FILE")" -eq 0 ]
if grep -Fq 'output_src_dev' "$LOCAL_PATCH_FILE"; then
	printf '%s\n' 'output_src_dev is dead in an OUTPUT-only chain' >&2
	exit 1
fi
grep -Fq 'existing swanpan patch detected' "$POSTINST"

for overlay in "$OVERLAY_ROOT"/*/rule.js "$OVERLAY_ROOT"/*/ruleconfig.lua; do
	[ -f "$overlay" ] || continue
	grep -Fq 'ipset_src_local' "$overlay"
	grep -Fq 'Allow router-originated traffic' "$overlay"
done

mirror=${OPENWRT_PACKAGES_MIRROR:-"${HOME}/projects/mirrors/openwrt-packages.git"}
if [ ! -d "$mirror" ]; then
	printf '%s\n' 'mwan3 local source structural tests passed (upstream mirror unavailable)'
	exit 0
fi

# Build a fake install root holding one upstream mwan3.sh plus the package files.
new_root() {
	root="$TEST_ROOT/$1"
	rm -rf "$root"
	mkdir -p "$root/lib/mwan3" \
		"$root/usr/share/swanpan-mwan3-patch" \
		"$root/usr/libexec/swanpan-mwan3-patch"
	cp -r "$PATCH_DIR" "$LOCAL_PATCH_DIR" "$root/usr/share/swanpan-mwan3-patch/"
	cp "$POSTINST" "$root/usr/libexec/swanpan-mwan3-patch/postinst.sh"
	chmod 0755 "$root/usr/libexec/swanpan-mwan3-patch/postinst.sh"
}

postinst() {
	IPKG_INSTROOT="$1" "$1/usr/libexec/swanpan-mwan3-patch/postinst.sh"
}

sha256() {
	sha256sum "$1" | awk '{print $1}'
}

new_root current
root="$TEST_ROOT/current"
git --git-dir="$mirror" show "openwrt-25.12:$MWAN3_PATH" > "$root/lib/mwan3/mwan3.sh"
pristine="$TEST_ROOT/pristine-25.12.sh"
cp "$root/lib/mwan3/mwan3.sh" "$pristine"

postinst "$root"
sh -n "$root/lib/mwan3/mwan3.sh"
grep -Fq 'config_get_bool ipset_src_local' "$root/lib/mwan3/mwan3.sh"
grep -Fq 'mwan3_output_hook' "$root/lib/mwan3/mwan3.sh"
grep -Fq 'mwan3_rules_output' "$root/lib/mwan3/mwan3.sh"
[ "$(grep -Fc '! -i +' "$root/lib/mwan3/mwan3.sh")" -eq 0 ]
[ -f "$root/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch" ]
cmp -s "$root/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch" "$pristine"

# The forwarding copy keeps the source ipset and the input-interface match.
# shellcheck disable=SC2016 # Match literal shell variables in the patched file.
grep -Fq '${src_dev:+-i} $src_dev' "$root/lib/mwan3/mwan3.sh"
# shellcheck disable=SC2016 # Match literal shell variables in the patched file.
grep -Fq '$ipset $ipset_src' "$root/lib/mwan3/mwan3.sh"

# The router-originated copy must land in mwan3_rules_output, must not carry an
# input-interface match (OUTPUT packets have no ingress device), and must jump
# through output_policy so a sticky rule does not pin local connections.
awk '
	index($0, "mwan3_push_update -A mwan3_rules_output") { chain = "output"; next }
	index($0, "mwan3_push_update -A mwan3_rules") { chain = "forward"; next }
	chain != "output" { next }
	index($0, "-i ") { bad = "input-interface match in mwan3_rules_output: " $0 }
	index($0, "-j ") {
		if (!index($0, "-j LOG") && !index($0, "-j ${output_policy:-$policy}")) {
			bad = "unexpected jump in mwan3_rules_output: " $0
		}
		chain = ""
	}
	END { if (bad != "") { print bad > "/dev/stderr"; exit 1 } }
' "$root/lib/mwan3/mwan3.sh"

expected=$(sha256 "$root/lib/mwan3/mwan3.sh")

# Reinstalling the same release leaves the file alone.
postinst "$root"
[ "$(sha256 "$root/lib/mwan3/mwan3.sh")" = "$expected" ]

# In-place upgrade from a release whose patches produced different content. The
# active file still carries every feature marker, so a marker-only guard would
# skip the upgrade and ship the new release with the old behavior.
sed -i '/output_policy="\$policy"/d' "$root/lib/mwan3/mwan3.sh"
[ "$(sha256 "$root/lib/mwan3/mwan3.sh")" != "$expected" ]
postinst "$root"
[ "$(sha256 "$root/lib/mwan3/mwan3.sh")" = "$expected" ]
cmp -s "$root/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch" "$pristine"

# In-place upgrade from release 1: the active file has only ipset_src support
# and the package backup is still pristine upstream.
cp "$pristine" "$root/lib/mwan3/mwan3.sh"
patch -d "$root" -p0 < "$BASE_PATCH_FILE" >/dev/null
postinst "$root"
[ "$(sha256 "$root/lib/mwan3/mwan3.sh")" = "$expected" ]
cmp -s "$root/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch" "$pristine"

# A patched file with no backup cannot be rebuilt, so installation must fail
# instead of stacking patches onto already patched content.
new_root nobackup
cp "$TEST_ROOT/current/lib/mwan3/mwan3.sh" "$TEST_ROOT/nobackup/lib/mwan3/mwan3.sh"
if postinst "$TEST_ROOT/nobackup" 2>/dev/null; then
	printf '%s\n' 'postinst accepted a patched file with no backup' >&2
	exit 1
fi

# Legacy variants. Each 10-legacy-<prefix>.patch is named after the sha256
# prefix of the upstream mwan3.sh it targets, so recover those files from the
# mirror and run the whole install against them.
index="$TEST_ROOT/variants"
mkdir -p "$index"
for branch in openwrt-22.03 openwrt-23.05 openwrt-24.10 openwrt-25.12 master; do
	git --git-dir="$mirror" log --format='%x00' --raw --no-abbrev \
		"$branch" -- "$MWAN3_PATH" 2>/dev/null | awk '/^:/ { print $4 }'
done | sort -u > "$TEST_ROOT/blobs"

while read -r blob; do
	git --git-dir="$mirror" cat-file blob "$blob" > "$TEST_ROOT/blob.sh" 2>/dev/null || continue
	prefix=$(sha256sum "$TEST_ROOT/blob.sh" | cut -c1-12)
	[ -f "$index/$prefix.sh" ] || cp "$TEST_ROOT/blob.sh" "$index/$prefix.sh"
done < "$TEST_ROOT/blobs"

legacy_tested=0
for patch in "$PATCH_DIR"/10-legacy-*.patch; do
	prefix=$(basename "$patch" .patch)
	prefix=${prefix#10-legacy-}
	[ -f "$index/$prefix.sh" ] || continue

	new_root "legacy-$prefix"
	root="$TEST_ROOT/legacy-$prefix"
	cp "$index/$prefix.sh" "$root/lib/mwan3/mwan3.sh"
	postinst "$root"
	sh -n "$root/lib/mwan3/mwan3.sh"
	grep -Fq 'config_get_bool ipset_src_local' "$root/lib/mwan3/mwan3.sh"
	# shellcheck disable=SC2016 # Match literal shell variables in the patched file.
	grep -Fq '[ "$ipset_src_local" -eq 1 ] && output_policy="$policy"' "$root/lib/mwan3/mwan3.sh"
	# shellcheck disable=SC2016 # Match literal shell variables in the patched file.
	grep -Fq -- '-j ${output_policy:-$policy}' "$root/lib/mwan3/mwan3.sh"
	[ "$(grep -Fc '! -i +' "$root/lib/mwan3/mwan3.sh")" -ge 2 ]
	legacy_tested=$((legacy_tested + 1))
done

if [ "$legacy_tested" -eq 0 ]; then
	printf '%s\n' 'no legacy mwan3.sh variants found in the mirror' >&2
	exit 1
fi

printf 'mwan3 local source tests passed (%d legacy variants)\n' "$legacy_tested"
