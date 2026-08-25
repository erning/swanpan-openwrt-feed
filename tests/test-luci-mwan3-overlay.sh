#!/bin/sh

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(CDPATH='' cd -- "${script_dir}/.." && pwd -P)"
pkg_dir="${repo_root}/swanpan-luci-app-mwan3-patch"
overlay_src="${pkg_dir}/files/usr/share/swanpan-luci-app-mwan3-patch/overlays"
libexec_src="${pkg_dir}/files/usr/libexec/swanpan-luci-app-mwan3-patch"
patch_dir="${pkg_dir}/tools/patches"
base_mirror="${OPENWRT_BASE_MIRROR:-${HOME}/projects/mirrors/openwrt-base.git}"
luci_mirror="${OPENWRT_LUCI_MIRROR:-${HOME}/projects/mirrors/openwrt-luci.git}"
test_root="$(mktemp -d)"

js_path="applications/luci-app-mwan3/htdocs/luci-static/resources/view/mwan3/network/rule.js"
lua_path="applications/luci-app-mwan3/luasrc/model/cbi/mwan/ruleconfig.lua"
jsmin_path="modules/luci-base/src/jsmin.c"

cleanup() {
	rm -rf "${test_root}"
}
trap cleanup EXIT HUP INT TERM

fail() {
	echo "test-luci-mwan3-overlay: $*" >&2
	exit 1
}

sha256_file() {
	sha256sum "$1" | awk '{print $1}'
}

new_root() {
	root="${test_root}/roots/$1"
	rm -rf "${root}"
	mkdir -p "${root}/usr/share/swanpan-luci-app-mwan3-patch" \
		"${root}/usr/libexec/swanpan-luci-app-mwan3-patch"
	cp -R "${overlay_src}" \
		"${root}/usr/share/swanpan-luci-app-mwan3-patch/overlays"
	cp "${libexec_src}/apply-overlay.sh" "${libexec_src}/postrm.sh" \
		"${root}/usr/libexec/swanpan-luci-app-mwan3-patch/"
	chmod 0755 "${root}/usr/libexec/swanpan-luci-app-mwan3-patch/"*.sh
}

apply_overlay() {
	IPKG_INSTROOT="$1" \
		"$1/usr/libexec/swanpan-luci-app-mwan3-patch/apply-overlay.sh"
}

remove_overlay() {
	IPKG_INSTROOT="$1" \
		"$1/usr/libexec/swanpan-luci-app-mwan3-patch/postrm.sh"
}

find_patch() {
	source_file="$1"
	destination="$2"
	kind="$3"
	patch_file=""

	case "${kind}" in
		js) patch_glob='*-ipset_src.patch' ;;
		lua) patch_glob='*-ruleconfig-ipset_src.patch' ;;
		*) fail "unknown patch kind: ${kind}" ;;
	esac

	for candidate in "${patch_dir}"/${patch_glob}; do
		[ -f "${candidate}" ] || continue
		case "${kind}:$(basename "${candidate}")" in
			js:*ruleconfig*) continue ;;
		esac
		probe="${test_root}/patch-probe"
		rm -rf "${probe}"
		mkdir -p "${probe}/$(dirname "${destination}")"
		cp "${source_file}" "${probe}/${destination}"
		if (cd "${probe}" && patch -p0 --dry-run -i "${candidate}" >/dev/null 2>&1); then
			patch_file="${candidate}"
			break
		fi
	done

	[ -n "${patch_file}" ] || fail "no patch applies to ${kind} source"
	printf '%s\n' "${patch_file}"
}

build_expected() {
	source_file="$1"
	destination="$2"
	kind="$3"
	expected_root="${test_root}/expected"
	rm -rf "${expected_root}"
	mkdir -p "${expected_root}/$(dirname "${destination}")"
	cp "${source_file}" "${expected_root}/${destination}"
	patch_file="$(find_patch "${source_file}" "${destination}" "${kind}")"
	(cd "${expected_root}" && patch -p0 -i "${patch_file}" >/dev/null)
	printf '%s\n' "${expected_root}/${destination}"
}

minify_js() {
	luci_ref="$1"
	source_file="$2"
	output_file="$3"
	jsmin_blob="$(git --git-dir="${luci_mirror}" rev-parse "${luci_ref}:${jsmin_path}")"
	jsmin_bin="${test_root}/jsmin/${jsmin_blob}"
	if [ ! -x "${jsmin_bin}" ]; then
		mkdir -p "${test_root}/jsmin"
		git --git-dir="${luci_mirror}" show "${luci_ref}:${jsmin_path}" \
			> "${jsmin_bin}.c"
		"${CC:-cc}" -O2 "${jsmin_bin}.c" -o "${jsmin_bin}"
	fi
	"${jsmin_bin}" < "${source_file}" > "${output_file}"
}

# Every overlay must have exactly one target and an explicit stock fingerprint
# list. A fingerprint may not select two different overlays.
all_fingerprints="${test_root}/all-fingerprints"
: > "${all_fingerprints}"
for overlay_dir in "${overlay_src}"/*/; do
	[ -d "${overlay_dir}" ] || continue
	count=0
	[ ! -f "${overlay_dir}rule.js" ] || count=$((count + 1))
	[ ! -f "${overlay_dir}ruleconfig.lua" ] || count=$((count + 1))
	[ "${count}" -eq 1 ] || fail "overlay must contain exactly one target: ${overlay_dir}"
	[ -s "${overlay_dir}stock.sha256" ] || fail "missing stock.sha256: ${overlay_dir}"
	if grep -Evq '^[0-9a-f]{64}$' "${overlay_dir}stock.sha256"; then
		fail "invalid stock.sha256: ${overlay_dir}"
	fi
	sed "s|$| $(basename "${overlay_dir}")|" "${overlay_dir}stock.sha256" \
		>> "${all_fingerprints}"
done

duplicates="$(cut -d ' ' -f1 "${all_fingerprints}" | sort | uniq -d)"
[ -z "${duplicates}" ] || fail "stock fingerprint maps to multiple overlays: ${duplicates}"

for overlay in "${overlay_src}"/*/rule.js "${overlay_src}"/*/ruleconfig.lua; do
	[ -f "${overlay}" ] || continue
	grep -Fq 'ipset_src_local' "${overlay}"
	grep -Fq 'Allow router-originated traffic' "${overlay}"
	if [ "${overlay##*.}" = "js" ] && command -v node >/dev/null 2>&1; then
		node --check "${overlay}" >/dev/null
	fi
done

if [ ! -d "${base_mirror}" ] || [ ! -d "${luci_mirror}" ]; then
	echo "LuCI mwan3 overlay structural tests passed (OpenWrt mirrors unavailable)"
	exit 0
fi

release_tags="$(git --git-dir="${base_mirror}" tag -l \
	'v21.02.*' 'v22.03.*' 'v23.05.*' 'v24.10.*' 'v25.12.*' \
	--sort=v:refname)"
[ -n "${release_tags}" ] || fail "no OpenWrt release tags found"

tested=0
for tag in ${release_tags}; do
	luci_ref="$(git --git-dir="${base_mirror}" show "${tag}:feeds.conf.default" | \
		awk '$2 == "luci" { sub(/^.*\^/, "", $3); print $3; exit }')"
	[ -n "${luci_ref}" ] || fail "cannot resolve LuCI ref for ${tag}"

	source_file="${test_root}/source"
	installed_file="${test_root}/installed"
	if git --git-dir="${luci_mirror}" cat-file -e "${luci_ref}:${js_path}" 2>/dev/null; then
		kind="js"
		destination="www/luci-static/resources/view/mwan3/network/rule.js"
		git --git-dir="${luci_mirror}" show "${luci_ref}:${js_path}" > "${source_file}"
		minify_js "${luci_ref}" "${source_file}" "${installed_file}"
	else
		kind="lua"
		destination="usr/lib/lua/luci/model/cbi/mwan/ruleconfig.lua"
		git --git-dir="${luci_mirror}" show "${luci_ref}:${lua_path}" > "${source_file}"
		cp "${source_file}" "${installed_file}"
	fi

	expected="$(build_expected "${source_file}" "${destination}" "${kind}")"
	new_root "${tag}"
	mkdir -p "${root}/$(dirname "${destination}")"
	cp "${installed_file}" "${root}/${destination}"
	if [ "${kind}" = "js" ]; then
		gzip -n -9 -c "${root}/${destination}" > "${root}/${destination}.gz"
	fi

	apply_overlay "${root}" >/dev/null 2>&1
	cmp -s "${root}/${destination}" "${expected}" || \
		fail "wrong overlay selected for ${tag}"
	backup="${root}/${destination}.orig.swanpan-luci-app-mwan3-patch"
	cmp -s "${backup}" "${installed_file}" || fail "wrong backup for ${tag}"
	if [ "${kind}" = "js" ]; then
		gzip -dc "${root}/${destination}.gz" | cmp -s - "${root}/${destination}" || \
			fail "stale gzip overlay for ${tag}"
		gzip_backup="${root}/${destination}.gz.orig.swanpan-luci-app-mwan3-patch"
		gzip -dc "${gzip_backup}" | cmp -s - "${installed_file}" || \
			fail "wrong gzip backup for ${tag}"
	fi

	before_target="$(sha256_file "${root}/${destination}")"
	before_backup="$(sha256_file "${backup}")"
	apply_overlay "${root}" >/dev/null 2>&1
	[ "$(sha256_file "${root}/${destination}")" = "${before_target}" ] || \
		fail "reinstall changed an existing overlay for ${tag}"
	[ "$(sha256_file "${backup}")" = "${before_backup}" ] || \
		fail "reinstall changed the backup for ${tag}"

	remove_overlay "${root}"
	cmp -s "${root}/${destination}" "${installed_file}" || \
		fail "removal did not restore ${tag}"
	if [ "${kind}" = "js" ]; then
		gzip -dc "${root}/${destination}.gz" | cmp -s - "${installed_file}" || \
			fail "removal did not restore gzip for ${tag}"
	fi

	tested=$((tested + 1))
done

# Unknown or locally modified content must never be overwritten or backed up.
new_root unknown
destination="www/luci-static/resources/view/mwan3/network/rule.js"
mkdir -p "${root}/$(dirname "${destination}")"
printf '%s\n' 'custom rule.js' > "${root}/${destination}"
gzip -n -9 -c "${root}/${destination}" > "${root}/${destination}.gz"
before="$(sha256_file "${root}/${destination}")"
if apply_overlay "${root}" 2> "${test_root}/unknown.err"; then
	fail "unknown content was accepted"
fi
grep -Fq 'unsupported or modified rule.js' "${test_root}/unknown.err"
[ "$(sha256_file "${root}/${destination}")" = "${before}" ] || \
	fail "unknown content was modified"
[ ! -e "${root}/${destination}.orig.swanpan-luci-app-mwan3-patch" ] || \
	fail "unknown content was backed up"

# An overlay produced by any package release is recognized by content and left
# untouched; the package does not migrate its own older output.
new_root already-applied
overlay="$(find "${overlay_src}" -name rule.js -type f | sort | head -n 1)"
mkdir -p "${root}/$(dirname "${destination}")"
cp "${overlay}" "${root}/${destination}"
printf '%s\n' 'existing backup' \
	> "${root}/${destination}.orig.swanpan-luci-app-mwan3-patch"
before="$(sha256_file "${root}/${destination}")"
before_backup="$(sha256_file "${root}/${destination}.orig.swanpan-luci-app-mwan3-patch")"
apply_overlay "${root}" 2> "${test_root}/already.err"
grep -Fq 'already applied; leaving it unchanged' "${test_root}/already.err"
[ "$(sha256_file "${root}/${destination}")" = "${before}" ] || \
	fail "existing overlay was migrated"
[ "$(sha256_file "${root}/${destination}.orig.swanpan-luci-app-mwan3-patch")" = "${before_backup}" ] || \
	fail "existing overlay backup was refreshed"

# A pre-existing gzip must match its plain target. Refuse before selecting an
# overlay or creating a backup if the pair is already inconsistent.
new_root mismatched-gzip
mkdir -p "${root}/$(dirname "${destination}")"
printf '%s\n' 'plain JavaScript target' > "${root}/${destination}"
printf '%s\n' 'not the JavaScript target' | gzip -n -9 -c \
	> "${root}/${destination}.gz"
before="$(sha256_file "${root}/${destination}")"
if apply_overlay "${root}" 2> "${test_root}/gzip.err"; then
	fail "mismatched gzip was accepted"
fi
grep -Fq 'refusing to modify mismatched files' "${test_root}/gzip.err"
[ "$(sha256_file "${root}/${destination}")" = "${before}" ] || \
	fail "target changed after gzip mismatch"
[ ! -e "${root}/${destination}.orig.swanpan-luci-app-mwan3-patch" ] || \
	fail "target was backed up after gzip mismatch"

# A compressed asset also makes gzip a hard prerequisite. Silently replacing
# only rule.js would leave uHTTPd serving stale JavaScript.
new_root missing-gzip
mkdir -p "${root}/$(dirname "${destination}")" "${test_root}/empty-path"
printf '%s\n' 'plain JavaScript target' > "${root}/${destination}"
gzip -n -9 -c "${root}/${destination}" > "${root}/${destination}.gz"
before="$(sha256_file "${root}/${destination}")"
if IPKG_INSTROOT="${root}" PATH="${test_root}/empty-path" /bin/sh \
	"${root}/usr/libexec/swanpan-luci-app-mwan3-patch/apply-overlay.sh" \
	2> "${test_root}/missing-gzip.err"; then
	fail "compressed target was accepted without gzip"
fi
grep -Fq 'gzip not found' "${test_root}/missing-gzip.err"
[ "$(sha256_file "${root}/${destination}")" = "${before}" ] || \
	fail "target changed without gzip"
[ ! -e "${root}/${destination}.orig.swanpan-luci-app-mwan3-patch" ] || \
	fail "target was backed up without gzip"

printf 'LuCI mwan3 overlay tests passed (%d OpenWrt release tags)\n' "${tested}"
