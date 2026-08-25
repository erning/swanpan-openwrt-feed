#!/bin/sh
# shellcheck disable=SC3043 # OpenWrt /bin/sh is BusyBox ash and supports local.

set -eu

pkg="swanpan-luci-app-mwan3-patch"
root="${IPKG_INSTROOT:-}"

dst_js="${root}/www/luci-static/resources/view/mwan3/network/rule.js"
dst_lua="${root}/usr/lib/lua/luci/model/cbi/mwan/ruleconfig.lua"
overlay_root="${root}/usr/share/${pkg}/overlays"

die() {
	echo "${pkg}: $*" >&2
	exit 1
}

sha256_file() {
	sha256sum "$1" | awk '{print $1}'
}

verify_gzip_peer() {
	[ -n "${dst_gz:-}" ] || return 0
	[ -f "${dst_gz}" ] || return 0
	command -v gzip >/dev/null 2>&1 || \
		die "cannot verify ${dst_gz}: gzip not found"
	gzip -t "${dst_gz}" 2>/dev/null || die "invalid gzip file: ${dst_gz}"
	if ! gzip -dc "${dst_gz}" 2>/dev/null | cmp -s - "${dst}"; then
		die "refusing to modify mismatched files: ${dst_gz} does not contain ${dst}"
	fi
}

find_applied_overlay() {
	local d

	for d in "${overlay_root}"/*/; do
		[ -d "${d}" ] || continue
		[ -f "${d}${want}" ] || continue
		if cmp -s "${d}${want}" "${dst}"; then
			printf '%s\n' "${d}${want}"
			return 0
		fi
	done

	return 1
}

find_stock_overlay() {
	local fingerprint="$1"
	local d manifest

	for d in "${overlay_root}"/*/; do
		[ -d "${d}" ] || continue
		[ -f "${d}${want}" ] || continue
		manifest="${d}stock.sha256"
		[ -f "${manifest}" ] || continue
		if grep -Fqx "${fingerprint}" "${manifest}"; then
			printf '%s\n' "${d}${want}"
			return 0
		fi
	done

	return 1
}

mode=""
dst=""
dst_gz=""
backup=""
backup_gz=""
want=""

if [ -f "${dst_js}" ]; then
	mode="js"
	dst="${dst_js}"
	dst_gz="${dst_js}.gz"
	backup="${dst_js}.orig.${pkg}"
	backup_gz="${dst_gz}.orig.${pkg}"
	want="rule.js"
elif [ -f "${dst_lua}" ]; then
	mode="lua"
	dst="${dst_lua}"
	backup="${dst_lua}.orig.${pkg}"
	want="ruleconfig.lua"
else
	die "target file not found: ${dst_js} or ${dst_lua} (is luci-app-mwan3 installed?)"
fi

verify_gzip_peer

applied="$(find_applied_overlay || true)"
if [ -n "${applied}" ]; then
	echo "${pkg}: overlay $(basename "$(dirname "${applied}")") already applied; leaving it unchanged" >&2
	exit 0
fi

command -v sha256sum >/dev/null 2>&1 || die "sha256sum not found"
fingerprint="$(sha256_file "${dst}")"
overlay="$(find_stock_overlay "${fingerprint}" || true)"
if [ -z "${overlay}" ]; then
	die "unsupported or modified ${want} (sha256=${fingerprint}); leaving it unchanged"
fi

suffix=".new.${pkg}.$$"
tmp_dst="${dst}${suffix}"
tmp_gz=""
tmp_backup="${backup}${suffix}"
tmp_backup_gz=""

# shellcheck disable=SC2329 # Invoked indirectly by trap.
cleanup() {
	rm -f "${tmp_dst}" "${tmp_backup}" 2>/dev/null || true
	[ -z "${tmp_gz}" ] || rm -f "${tmp_gz}" 2>/dev/null || true
	[ -z "${tmp_backup_gz}" ] || rm -f "${tmp_backup_gz}" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

cp -fp "${overlay}" "${tmp_dst}" || die "failed to stage ${dst}"
chmod 0644 "${tmp_dst}" 2>/dev/null || true
cp -fp "${dst}" "${tmp_backup}" || die "failed to stage backup ${backup}"

if [ "${mode}" = "js" ] && [ -f "${dst_gz}" ]; then
	tmp_gz="${dst_gz}${suffix}"
	tmp_backup_gz="${backup_gz}${suffix}"
	gzip -n -9 -c "${tmp_dst}" > "${tmp_gz}" 2>/dev/null || \
		die "failed to stage ${dst_gz}"
	chmod 0644 "${tmp_gz}" 2>/dev/null || true
	cp -fp "${dst_gz}" "${tmp_backup_gz}" || \
		die "failed to stage backup ${backup_gz}"
fi

mv -f "${tmp_backup}" "${backup}" || die "failed to install backup ${backup}"
if [ -n "${tmp_backup_gz}" ]; then
	mv -f "${tmp_backup_gz}" "${backup_gz}" || \
		die "failed to install backup ${backup_gz}"
elif [ -n "${backup_gz}" ]; then
	rm -f "${backup_gz}"
fi

mv -f "${tmp_dst}" "${dst}" || die "failed to install ${dst}"
if [ -n "${tmp_gz}" ]; then
	mv -f "${tmp_gz}" "${dst_gz}" || die "failed to install ${dst_gz}"
fi

echo "${pkg}: applied overlay $(basename "$(dirname "${overlay}")") (${mode}, stock sha256=${fingerprint})" >&2
exit 0
