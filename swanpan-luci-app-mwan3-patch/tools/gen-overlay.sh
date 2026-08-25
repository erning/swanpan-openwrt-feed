#!/bin/sh
# shellcheck disable=SC3043 # Supported host /bin/sh implementations provide local.

set -eu

# Generate an overlay and its accepted stock-file fingerprints from a local
# openwrt/luci git mirror.
#
# Usage examples:
#   swanpan-luci-app-mwan3-patch/tools/gen-overlay.sh openwrt-25.12
#   swanpan-luci-app-mwan3-patch/tools/gen-overlay.sh 7d29c78
#   swanpan-luci-app-mwan3-patch/tools/gen-overlay.sh 25.195.59161~7d29c78-r1
#
# Env:
#   LUCI_MIRROR=/path/to/openwrt-luci.git
#   CC=cc

ref_input="${1:-}"
if [ -z "${ref_input}" ]; then
	echo "usage: $0 <git-ref|package-version>" >&2
	exit 2
fi

pkg_dir="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
mirror="${LUCI_MIRROR:-${HOME}/projects/mirrors/openwrt-luci.git}"
patches_dir="${pkg_dir}/tools/patches"
outroot="${pkg_dir}/files/usr/share/swanpan-luci-app-mwan3-patch/overlays"

die() {
	echo "$*" >&2
	exit 1
}

sha256_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" | awk '{print $1}'
	else
		die "sha256sum or shasum is required"
	fi
}

[ -d "${mirror}" ] || die "mirror not found: ${mirror}"
[ -d "${patches_dir}" ] || die "patches dir not found: ${patches_dir}"

# Accept either an APK or legacy opkg Version string and derive a git ref.
ref="${ref_input}"
case "${ref}" in
	*~*)
		release="${ref##*-r}"
		case "${release}" in
			""|*[!0-9]*) : ;;
			*) ref="${ref%-r*}" ;;
		esac
		hash="${ref##*~}"
		[ "${#hash}" -ne 7 ] || ref="${hash}"
		;;
	git-*-*-*)
		last="${ref##*-}"
		case "${last}" in
			""|*[!0-9]*) : ;;
			*) ref="${ref%-*}" ;;
		esac
		hash="${ref##*-}"
		[ "${#hash}" -ne 7 ] || ref="${hash}"
		;;
esac

tmpbase="$(mktemp -d)"
wt="${tmpbase}/wt"

cleanup() {
	git --git-dir="${mirror}" worktree remove -f "${wt}" >/dev/null 2>&1 || true
	rm -rf "${tmpbase}" >/dev/null 2>&1 || true
	git --git-dir="${mirror}" worktree prune >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

git --git-dir="${mirror}" worktree add --detach -f "${wt}" "${ref}" >/dev/null

appdir="${wt}/applications/luci-app-mwan3"
src_js="${appdir}/htdocs/luci-static/resources/view/mwan3/network/rule.js"
src_lua="${appdir}/luasrc/model/cbi/mwan/ruleconfig.lua"

src=""
src_rel=""
dst_rel=""
out_file=""
patch_glob=""

if [ -f "${src_js}" ]; then
	src="${src_js}"
	src_rel="${src_js#"${wt}"/}"
	dst_rel="www/luci-static/resources/view/mwan3/network/rule.js"
	out_file="rule.js"
	patch_glob='*-ipset_src.patch'
elif [ -f "${src_lua}" ]; then
	src="${src_lua}"
	src_rel="${src_lua#"${wt}"/}"
	dst_rel="usr/lib/lua/luci/model/cbi/mwan/ruleconfig.lua"
	out_file="ruleconfig.lua"
	patch_glob='*-ruleconfig-ipset_src.patch'
else
	die "no supported target found in ref '${ref_input}'"
fi

patchfile=""
for cand in "${patches_dir}"/${patch_glob}; do
	[ -e "${cand}" ] || continue
	case "${out_file}:$(basename "${cand}")" in
		rule.js:*ruleconfig*) continue ;;
	esac
	tmp_try="${tmpbase}/try"
	rm -rf "${tmp_try}"
	mkdir -p "${tmp_try}/$(dirname "${dst_rel}")"
	cp -f "${src}" "${tmp_try}/${dst_rel}"
	if (cd "${tmp_try}" && patch -p0 --dry-run -i "${cand}" >/dev/null 2>&1); then
		patchfile="${cand}"
		break
	fi
done

[ -n "${patchfile}" ] || \
	die "no patch in ${patches_dir} applies to ${out_file} at ref '${ref_input}'"

fmt="$(awk '
	/printf .*%05d.*%s/ {
		s = $0
		sub(/^[^"\x27]*[\x27"]/, "", s)
		sub(/[\x27"].*$/, "", s)
		if (s ~ /%05d/ && s ~ /%s/) {
			print s
			exit
		}
	}' "${wt}/luci.mk")"
[ -n "${fmt}" ] || fmt='%s.%05d~%s'

format_version() {
	python3 - "$1" "$2" "${fmt}" <<'PY'
import datetime
import sys

timestamp = int(sys.argv[1])
short_hash = sys.argv[2]
version_format = sys.argv[3]
seconds = timestamp % 86400
year_day = datetime.datetime.fromtimestamp(
    timestamp, datetime.timezone.utc
).strftime("%y.%j")
print(version_format % (year_day, seconds, short_hash))
PY
}

# Name new overlays after the commit that changed the target file itself.
findrev_th="$(git -C "${wt}" log -1 --format='%ct %h' --abbrev=7 -- "${src_rel}")"
[ -n "${findrev_th}" ] || die "target file has no git revision: ${src_rel}"
base_version="$(format_version "${findrev_th%% *}" "${findrev_th##* }")"
[ -n "${base_version}" ] || die "could not derive a version stamp for ref '${ref_input}'"

tmpfs="${tmpbase}/fs"
mkdir -p "${tmpfs}/$(dirname "${dst_rel}")"
cp -f "${src}" "${tmpfs}/${dst_rel}"
(cd "${tmpfs}" && patch -p0 < "${patchfile}" >/dev/null)
candidate="${tmpfs}/${dst_rel}"

existing=""
if [ -d "${outroot}" ]; then
	for d in "${outroot}"/*/; do
		[ -d "${d}" ] || continue
		[ -f "${d}${out_file}" ] || continue
		if cmp -s "${candidate}" "${d}${out_file}"; then
			existing="$(basename "${d}")"
			break
		fi
	done
fi

if [ -n "${existing}" ]; then
	outdir="${outroot}/${existing}"
	echo "ref '${ref_input}' (${base_version}) shares ${out_file} with overlay '${existing}'" >&2
else
	outdir="${outroot}/${base_version}"
	mkdir -p "${outdir}"
	cp -f "${candidate}" "${outdir}/${out_file}"
	echo "generated overlay: ${base_version}" >&2
	echo "- ${outdir}/${out_file}" >&2
fi

manifest="${outdir}/stock.sha256"
manifest_tmp="${manifest}.new.$$"
fingerprints="${tmpbase}/fingerprints"
if [ -f "${manifest}" ]; then
	sed '/^[[:space:]]*$/d' "${manifest}" > "${fingerprints}"
else
	: > "${fingerprints}"
fi

sha256_file "${src}" >> "${fingerprints}"
if [ "${out_file}" = "rule.js" ]; then
	jsmin_src="${wt}/modules/luci-base/src/jsmin.c"
	[ -f "${jsmin_src}" ] || die "LuCI jsmin source not found: ${jsmin_src}"
	jsmin_bin="${tmpbase}/jsmin"
	"${CC:-cc}" -O2 "${jsmin_src}" -o "${jsmin_bin}"
	minified="${tmpbase}/rule.min.js"
	"${jsmin_bin}" < "${src}" > "${minified}"
	sha256_file "${minified}" >> "${fingerprints}"
fi

sort -u "${fingerprints}" > "${manifest_tmp}"
mv -f "${manifest_tmp}" "${manifest}"

echo "- ${manifest}" >&2
