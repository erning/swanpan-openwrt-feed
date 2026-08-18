#!/bin/sh
# shellcheck disable=SC3043 # OpenWrt /bin/sh is BusyBox ash and supports local.

set -eu

pkg="swanpan-luci-app-mwan3-patch"

root="${IPKG_INSTROOT:-}"

dst_js="${root}/www/luci-static/resources/view/mwan3/network/rule.js"
dst_lua="${root}/usr/lib/lua/luci/model/cbi/mwan/ruleconfig.lua"

status_file="${root}/usr/lib/opkg/status"
overlay_root="${root}/usr/share/${pkg}/overlays"

die() {
	echo "${pkg}: $*" >&2
	exit 1
}

get_installed_version() {
	local v=""

	# OpenWrt 24.10+ uses apk; the installed db is in ADB binary format,
	# so read it via the apk command rather than awking the file. `apk list
	# --installed` prints "<pkg>-<ver> <arch> ... [installed]" — anchor on
	# "<pkg>-" so we don't match the description line emitted by `apk info`.
	if [ -z "${IPKG_INSTROOT:-}" ] && command -v apk >/dev/null 2>&1; then
		v="$(apk list --installed luci-app-mwan3 2>/dev/null | \
			awk 'index($0, "luci-app-mwan3-") == 1 { s=$1; sub("^luci-app-mwan3-","",s); print s; exit }')"
	fi

	if [ -z "${v}" ] && [ -f "${status_file}" ]; then
		v="$(awk 'BEGIN{p=0} $0=="Package: luci-app-mwan3"{p=1} p && $1=="Version:"{print $2; exit}' "${status_file}" 2>/dev/null || true)"
	fi

	if [ -z "${v}" ] && [ -z "${IPKG_INSTROOT:-}" ] && command -v opkg >/dev/null 2>&1; then
		v="$(opkg status luci-app-mwan3 2>/dev/null | awk '$1=="Version:"{print $2; exit}')"
	fi

	echo "${v}"
}

# Convert a version-like string ("YY.JJJ.SSSSS~hash" or "git-YY.JJJ.SSSSS-hash")
# to an integer score (YY*1000 + JJJ). Empty if the string isn't shaped that way.
era_score() {
	local s="$1"
	s="${s#git-}"
	printf '%s' "$s" | awk -F. '
		NF >= 2 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
			printf "%d", ($1 * 1000) + $2
		}'
}

pick_overlay() {
	# Each overlay is keyed by the version that *introduced* its rule.js
	# content. Versions where rule.js didn't change reuse the predecessor.
	# Find the overlay with the highest era_score that is still <= the
	# device's era_score. If we couldn't compute the device's score (apk
	# Version was empty/odd), fall back to the latest known overlay.
	local v="$1"
	local want="$2"
	local dev_score
	local d name s
	local best="" best_score=-1 best_tested=""

	dev_score="$(era_score "${v}")"

	for d in "${overlay_root}"/*/; do
		[ -d "${d}" ] || continue
		[ -f "${d}${want}" ] || continue
		name="$(basename "${d}")"
		s="$(era_score "${name}")"
		[ -n "${s}" ] || continue
		if [ -n "${dev_score}" ] && [ "${s}" -gt "${dev_score}" ]; then
			continue
		fi
		if [ "${s}" -gt "${best_score}" ]; then
			best_score="${s}"
			best="${d}${want}"
			best_tested=""
			if [ -f "${d}tested_up_to" ]; then
				best_tested="$(awk '$1 ~ /^[0-9]+$/ {print $1; exit}' "${d}tested_up_to")"
			fi
		fi
	done

	[ -z "${best}" ] && return 1

	# tested_up_to records the highest era we've verified rule.js content
	# is unchanged at. If the device is past that, the upstream may have
	# shipped a new rule.js variant we haven't tested yet — apply the
	# best-known overlay anyway, but loudly tell the maintainer to refresh.
	if [ -n "${dev_score}" ] && [ -n "${best_tested}" ] && [ "${dev_score}" -gt "${best_tested}" ]; then
		echo "${pkg}: warning: overlay $(basename "$(dirname "${best}")") tested_up_to=${best_tested}, device era=${dev_score}" >&2
		echo "${pkg}: warning: rule.js may have changed upstream — re-run tools/gen-overlay.sh against the latest luci ref" >&2
	fi

	printf '%s\n' "${best}"
	return 0
}

regen_gz() {
	[ -n "${dst_gz:-}" ] || return 0
	[ -f "${dst_gz}" ] || return 0
	command -v gzip >/dev/null 2>&1 || return 0

	local tmp_gz="${dst_gz}.tmp.${pkg}"
	if gzip -n -9 -c "${dst}" > "${tmp_gz}" 2>/dev/null; then
		mv -f "${tmp_gz}" "${dst_gz}"
		chmod 0644 "${dst_gz}" 2>/dev/null || true
	else
		rm -f "${tmp_gz}" 2>/dev/null || true
	fi
}

# --- main ---

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

installed_version="$(get_installed_version)"

overlay="$(pick_overlay "${installed_version}" "${want}" || true)"
if [ -z "${overlay}" ]; then
	die "no overlay found (Version='${installed_version:-unknown}')"
fi

if cmp -s "${overlay}" "${dst}"; then
	regen_gz
	echo "${pkg}: overlay $(basename "$(dirname "${overlay}")") already applied" >&2
	exit 0
fi

# Keep the original backup across this package's own upgrades. If the target no
# longer contains our field, luci-app-mwan3 was upgraded and the backup must be
# refreshed before applying the overlay again.
refresh_backup=0
if [ ! -f "${backup}" ] || ! grep -q 'ipset_src' "${dst}"; then
	refresh_backup=1
	cp -fp "${dst}" "${backup}"
fi
if [ "${mode}" = "js" ] && [ -f "${dst_gz}" ] && \
	{ [ "${refresh_backup}" = "1" ] || [ ! -f "${backup_gz}" ]; }; then
	cp -fp "${dst_gz}" "${backup_gz}"
fi

if ! cp -fp "${overlay}" "${dst}"; then
	die "failed to write ${dst}"
fi

chmod 0644 "${dst}" 2>/dev/null || true

regen_gz

echo "${pkg}: applied overlay $(basename "$(dirname "${overlay}")") (${mode}, Version='${installed_version:-unknown}')" >&2
exit 0
