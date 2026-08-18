#!/bin/sh
# shellcheck disable=SC3043 # Supported host /bin/sh implementations provide local.

set -eu

# Generate a versioned overlay file from a local openwrt/luci git mirror.
#
# Usage examples:
#   swanpan-luci-app-mwan3-patch/tools/gen-overlay.sh openwrt-25.12
#   swanpan-luci-app-mwan3-patch/tools/gen-overlay.sh 7d29c78
#   swanpan-luci-app-mwan3-patch/tools/gen-overlay.sh 25.195.59161~7d29c78-r1
#
# Env:
#   LUCI_MIRROR=/path/to/openwrt-luci.git

ref_input="${1:-}"
if [ -z "${ref_input}" ]; then
	echo "usage: $0 <git-ref|package-version>" >&2
	exit 2
fi

pkg_dir="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

mirror="${LUCI_MIRROR:-${HOME}/projects/mirrors/openwrt-luci.git}"
patches_dir="${pkg_dir}/tools/patches"
outroot="${pkg_dir}/files/usr/share/swanpan-luci-app-mwan3-patch/overlays"

if [ ! -d "${mirror}" ]; then
	echo "mirror not found: ${mirror}" >&2
	exit 1
fi

if [ ! -d "${patches_dir}" ]; then
	echo "patches dir not found: ${patches_dir}" >&2
	exit 1
fi

# Accept either an APK or legacy opkg Version string and derive a git ref.
ref="${ref_input}"

case "${ref}" in
	*~*)
		# APK: YY.JJJ.SSSSS~<hash>-r<release>
		release="${ref##*-r}"
		case "${release}" in
			""|*[!0-9]*) : ;;
			*) ref="${ref%-r*}" ;;
		esac
		hash="${ref##*~}"
		if [ "${#hash}" -eq 7 ]; then
			ref="${hash}"
		fi
		;;
	git-*-*-*)
		# opkg: git-YY.JJJ.SSSSS-<hash>-<release>
		last="${ref##*-}"
		case "${last}" in
			""|*[!0-9]*) : ;;
			*) ref="${ref%-*}" ;;
		esac
		# Extract trailing 7-char commit hash.
		hash="${ref##*-}"
		if [ "${#hash}" -eq 7 ]; then
			ref="${hash}"
		fi
		;;
esac

tmpbase="$(mktemp -d)"
wt="${tmpbase}/wt"

cleanup() {
	# best-effort cleanup
	git --git-dir="${mirror}" worktree remove -f "${wt}" >/dev/null 2>&1 || true
	rm -rf "${tmpbase}" >/dev/null 2>&1 || true
	git --git-dir="${mirror}" worktree prune >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

git --git-dir="${mirror}" worktree add --detach -f "${wt}" "${ref}" >/dev/null

appdir="${wt}/applications/luci-app-mwan3"
src_js="${appdir}/htdocs/luci-static/resources/view/mwan3/network/rule.js"
src_lua="${appdir}/luasrc/model/cbi/mwan/ruleconfig.lua"

src=""
dst_rel=""
out_file=""
patch_glob=""

if [ -f "${src_js}" ]; then
	src="${src_js}"
	dst_rel="www/luci-static/resources/view/mwan3/network/rule.js"
	out_file="rule.js"
	patch_glob='*-ipset_src.patch'
elif [ -f "${src_lua}" ]; then
	src="${src_lua}"
	dst_rel="usr/lib/lua/luci/model/cbi/mwan/ruleconfig.lua"
	out_file="ruleconfig.lua"
	patch_glob='*-ruleconfig-ipset_src.patch'
else
	echo "no supported target found in ref '${ref_input}'" >&2
	echo "- missing: ${src_js}" >&2
	echo "- missing: ${src_lua}" >&2
	exit 1
fi

# Filter patches that match this target's glob (excluding the ruleconfig
# variant when we're generating the JS overlay).
patchfile=""
for cand in "${patches_dir}"/${patch_glob}; do
	[ -e "${cand}" ] || continue
	case "${out_file}" in
		rule.js)
			# Skip ruleconfig patches even though they match *-ipset_src.patch.
			case "$(basename "${cand}")" in
				*ruleconfig*) continue ;;
			esac
			;;
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

if [ -z "${patchfile}" ]; then
	echo "no patch in ${patches_dir} applies to ${out_file} at ref '${ref_input}'" >&2
	exit 1
fi

# luci.mk's printf format has changed over time:
#   - old:  printf 'git-%s.%05d-%s'    (legacy)
#   - 2024: printf 'git-%s.%05d~%s'    (APK-compliant, transient)
#   - 2024+: printf '%s.%05d~%s'       (current)
# Detect by reading the worktree's luci.mk so we name the overlay directory
# exactly as opkg/apk will report the installed Version.
fmt="$(awk '
	/printf .*%05d.*%s/ {
		s = $0
		# strip everything before the first quote (single or double)
		sub(/^[^"\x27]*[\x27"]/, "", s)
		# strip the closing quote and trailing args
		sub(/[\x27"].*$/, "", s)
		# require both %s and %05d to be present
		if (s ~ /%05d/ && s ~ /%s/) {
			print s
			exit
		}
	}' "${wt}/luci.mk")"

if [ -z "${fmt}" ]; then
	# Fallback: assume the current (no-prefix, ~) format.
	fmt='%s.%05d~%s'
fi

format_version() {
	# $1=ts $2=hash
	python3 - "$1" "$2" "${fmt}" <<'PY'
import sys
import datetime
from datetime import UTC

ts = int(sys.argv[1])
h = sys.argv[2]
fmt = sys.argv[3]
secs = ts % 86400
yday = datetime.datetime.fromtimestamp(ts, UTC).strftime('%y.%j')
print(fmt % (yday, secs, h))
PY
}

die() { echo "$*" >&2; exit 1; }

# findrev names the overlay by the commit that introduced this rule.js
# variant — that's the directory name. tested_up_to is bumped to the
# era score of the worktree HEAD itself, since OpenWrt's apk packaging
# stamps the package Version with HEAD's ct/hash.
findrev_th="$(git -C "${appdir}" log -1 --format='%ct %h' --abbrev=7 -- . ':(exclude)po')"
[ -n "${findrev_th% *}" ] || die "findrev returned no commit; nothing to do"
base_version="$(format_version "${findrev_th%% *}" "${findrev_th##* }")"
[ -n "${base_version}" ] || die "could not derive a version stamp for ref '${ref_input}'"

self_th="$(git -C "${wt}" log -1 --format='%ct %h' --abbrev=7 HEAD)"
self_version="$(format_version "${self_th%% *}" "${self_th##* }")"

era_score() {
	printf '%s' "$1" | sed -E 's/^git-//' | awk -F. '
		NF >= 2 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
			printf "%d", ($1 * 1000) + $2
		}'
}

self_score="$(era_score "${self_version}")"
[ -n "${self_score}" ] || die "could not derive era_score for HEAD self_version '${self_version}'"

tmpfs="${tmpbase}/fs"
mkdir -p "${tmpfs}/$(dirname "${dst_rel}")"
cp -f "${src}" "${tmpfs}/${dst_rel}"

(cd "${tmpfs}" && patch -p0 < "${patchfile}" >/dev/null)

# Skip if the resulting rule.js is byte-identical to an existing
# overlay's. Same content => same overlay covers it; the existing
# overlay's range is just extended forward (handled at runtime).
candidate="${tmpfs}/${dst_rel}"
existing=""
if [ -d "${outroot}" ]; then
	for d in "${outroot}"/*/; do
		[ -d "$d" ] || continue
		[ -f "${d}${out_file}" ] || continue
		if cmp -s "${candidate}" "${d}${out_file}"; then
			existing="$(basename "$d")"
			break
		fi
	done
fi

bump_tested_up_to() {
	# $1: overlay dir name
	# Bump that overlay's tested_up_to to max(current, self_score).
	local dir="${outroot}/$1"
	local tu_file="${dir}/tested_up_to"
	local cur=""
	if [ -f "${tu_file}" ]; then
		cur="$(awk '$1 ~ /^[0-9]+$/ {print $1; exit}' "${tu_file}")"
	fi
	if [ -z "${cur}" ] || [ "${self_score}" -gt "${cur}" ]; then
		printf '%s\n' "${self_score}" > "${tu_file}"
		echo "  tested_up_to: ${cur:-(none)} -> ${self_score} (HEAD ${self_version})" >&2
	else
		echo "  tested_up_to stays at ${cur} (HEAD ${self_version} score ${self_score})" >&2
	fi
}

if [ -n "${existing}" ]; then
	echo "ref '${ref_input}' (${base_version}) shares ${out_file} with existing overlay '${existing}'" >&2
	bump_tested_up_to "${existing}"
else
	mkdir -p "${outroot}/${base_version}"
	cp -f "${candidate}" "${outroot}/${base_version}/${out_file}"
	echo "generated overlay: ${base_version}" >&2
	echo "- ${outroot}/${base_version}/${out_file}" >&2
	bump_tested_up_to "${base_version}"
fi
