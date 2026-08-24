#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
BASE_PATCH_FILE="$REPO_ROOT/swanpan-mwan3-patch/files/usr/share/swanpan-mwan3-patch/patches/00-ipset_src.patch"
LOCAL_PATCH_FILE="$REPO_ROOT/swanpan-mwan3-patch/files/usr/share/swanpan-mwan3-patch/patches-local/00-ipset_src_local.patch"
POSTINST="$REPO_ROOT/swanpan-mwan3-patch/files/usr/libexec/swanpan-mwan3-patch/postinst.sh"
OVERLAY_ROOT="$REPO_ROOT/swanpan-luci-app-mwan3-patch/files/usr/share/swanpan-luci-app-mwan3-patch/overlays"
TEST_ROOT=$(mktemp -d)

cleanup() {
	rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

grep -Fq 'config_get ipset_src' "$BASE_PATCH_FILE"
# shellcheck disable=SC2016 # Match literal shell variables in the patch.
[ "$(grep -Fc '$ipset $ipset_src' "$BASE_PATCH_FILE")" -eq 2 ]
grep -Fq 'config_get_bool ipset_src_local' "$LOCAL_PATCH_FILE"
grep -Fq 'mwan3_output_hook' "$LOCAL_PATCH_FILE"
grep -Fq 'mwan3_rules_output' "$LOCAL_PATCH_FILE"
grep -Fq 'output_policy="mwan3_policy_$use_policy"' "$LOCAL_PATCH_FILE"
grep -Fq -- '-j $output_policy' "$LOCAL_PATCH_FILE"
[ "$(grep -Fc '! -i +' "$LOCAL_PATCH_FILE")" -eq 0 ]
grep -Fq 'legacy ipset_src patch detected' "$POSTINST"

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

root="$TEST_ROOT/root"
mkdir -p "$root/lib/mwan3" \
	"$root/usr/share/swanpan-mwan3-patch/patches" \
	"$root/usr/share/swanpan-mwan3-patch/patches-local" \
	"$root/usr/libexec/swanpan-mwan3-patch"

git --git-dir="$mirror" show \
	openwrt-25.12:net/mwan3/files/lib/mwan3/mwan3.sh > \
	"$root/lib/mwan3/mwan3.sh"
cp "$BASE_PATCH_FILE" "$root/usr/share/swanpan-mwan3-patch/patches/"
cp "$LOCAL_PATCH_FILE" "$root/usr/share/swanpan-mwan3-patch/patches-local/"
cp "$POSTINST" "$root/usr/libexec/swanpan-mwan3-patch/postinst.sh"
chmod 0755 "$root/usr/libexec/swanpan-mwan3-patch/postinst.sh"

IPKG_INSTROOT="$root" "$root/usr/libexec/swanpan-mwan3-patch/postinst.sh"
sh -n "$root/lib/mwan3/mwan3.sh"
grep -Fq 'config_get_bool ipset_src_local' "$root/lib/mwan3/mwan3.sh"
grep -Fq 'mwan3_output_hook' "$root/lib/mwan3/mwan3.sh"
grep -Fq 'mwan3_rules_output' "$root/lib/mwan3/mwan3.sh"
grep -Fq 'output_policy="mwan3_policy_$use_policy"' "$root/lib/mwan3/mwan3.sh"
grep -Fq -- '-j $output_policy' "$root/lib/mwan3/mwan3.sh"
[ "$(grep -Fc '! -i +' "$root/lib/mwan3/mwan3.sh")" -eq 0 ]
[ -f "$root/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch" ]

before=$(sha256sum "$root/lib/mwan3/mwan3.sh" | awk '{print $1}')
IPKG_INSTROOT="$root" "$root/usr/libexec/swanpan-mwan3-patch/postinst.sh"
after=$(sha256sum "$root/lib/mwan3/mwan3.sh" | awk '{print $1}')
[ "$before" = "$after" ]

# Simulate an in-place upgrade from release 1: the active file contains only
# ipset_src support, while the package backup is still pristine upstream.
backup_before=$(sha256sum "$root/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch" | awk '{print $1}')
cp "$root/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch" "$root/lib/mwan3/mwan3.sh"
patch -d "$root" -p0 < "$BASE_PATCH_FILE" >/dev/null
IPKG_INSTROOT="$root" "$root/usr/libexec/swanpan-mwan3-patch/postinst.sh"
grep -Fq 'config_get_bool ipset_src_local' "$root/lib/mwan3/mwan3.sh"
backup_after=$(sha256sum "$root/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch" | awk '{print $1}')
[ "$backup_before" = "$backup_after" ]

printf '%s\n' 'mwan3 local source tests passed'
