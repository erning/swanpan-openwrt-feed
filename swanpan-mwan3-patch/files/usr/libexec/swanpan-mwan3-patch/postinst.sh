#!/bin/sh
set -eu

pkg="swanpan-mwan3-patch"

# When running on a live system, IPKG_INSTROOT is unset.
# Use / as the logical root in that case.
root="${IPKG_INSTROOT:-/}"

dst="${root}/lib/mwan3/mwan3.sh"
backup="${root}/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch"

mwan3_version=""
status_file="${root}/usr/lib/opkg/status"

patch_dir="${root}/usr/share/swanpan-mwan3-patch/patches"
local_patch_dir="${root}/usr/share/swanpan-mwan3-patch/patches-local"


die() {
	echo "${pkg}: $*" >&2
	exit 1
}

apply_patch_in_dir() {
	# Keep this compatible with minimal patch implementations.
	# Prefer -p0, but fall back to default strip level.
	#
	# $1: working directory
	# $2: patch file
	(
		cd "$1"
		patch -p0 < "$2" >/dev/null 2>&1 || patch < "$2" >/dev/null 2>&1
	)
}

new_temp_dir() {
	tmpbase="${root}/tmp"
	[ -z "${root}" ] && tmpbase="/tmp"
	mkdir -p "${tmpbase}" 2>/dev/null || true

	mktemp -d "${tmpbase}/${pkg}.XXXXXX" 2>/dev/null || true
}

select_patch() {
	# Sets selected_patch to the first patch that applies to source_file.
	#
	# $1: source mwan3.sh
	# $2: directory containing candidate patches
	source_file="$1"
	source_patch_dir="$2"
	selected_patch=""

	set -- "${source_patch_dir}"/*.patch
	[ -e "${1}" ] || return 1

	for p in "${source_patch_dir}"/*.patch; do
		tmpdir="$(new_temp_dir)"
		[ -n "${tmpdir}" ] || die "failed to create temp dir"

		mkdir -p "${tmpdir}/lib/mwan3"
		cp -fp "${source_file}" "${tmpdir}/lib/mwan3/mwan3.sh"

		if apply_patch_in_dir "${tmpdir}" "${p}"; then
			selected_patch="${p}"
			rm -rf "${tmpdir}" >/dev/null 2>&1 || true
			return 0
		fi

		rm -rf "${tmpdir}" >/dev/null 2>&1 || true
	done

	return 1
}

if [ -z "${IPKG_INSTROOT:-}" ] && command -v apk >/dev/null 2>&1; then
	mwan3_version="$(apk list --installed mwan3 2>/dev/null | \
		awk 'index($0, "mwan3-") == 1 { s=$1; sub("^mwan3-","",s); print s; exit }')"
fi

if [ -z "${mwan3_version}" ] && [ -f "${status_file}" ]; then
	mwan3_version="$(awk 'BEGIN{p=0} $0=="Package: mwan3"{p=1} p && $1=="Version:"{print $2; exit}' "${status_file}" 2>/dev/null || true)"
fi

if [ -z "${mwan3_version}" ] && [ -z "${IPKG_INSTROOT:-}" ] && command -v opkg >/dev/null 2>&1; then
	mwan3_version="$(opkg status mwan3 2>/dev/null | awk '$1=="Version:"{print $2; exit}')"
fi

if [ ! -f "${dst}" ]; then
	echo "${pkg}: ${dst} not found; skipping" >&2
	exit 0
fi

command -v patch >/dev/null 2>&1 || die "patch command not found (install package 'patch')"

# An earlier release of this package may have patched ${dst} in place, and the
# patches shipped here are not necessarily the ones it applied. Rebuild from the
# pristine backup instead of trusting feature markers, so an in-place upgrade
# always ends up with the current patch set. Package managers do not
# consistently run the old postrm during an upgrade, so handle both upgrade
# paths here.
source="${dst}"
if grep -q "\bipset_src\b" "${dst}" || grep -q "\bipset_src_local\b" "${dst}"; then
	[ -f "${backup}" ] || die "existing swanpan patch detected but ${backup} is missing"
	source="${backup}"
fi

if select_patch "${source}" "${patch_dir}"; then
	chosen_base_patch="${selected_patch}"
else
	sha256=""
	if command -v sha256sum >/dev/null 2>&1; then
		sha256="$(sha256sum "${source}" | awk '{print $1}')"
	elif command -v shasum >/dev/null 2>&1; then
		sha256="$(shasum -a 256 "${source}" | awk '{print $1}')"
	elif command -v openssl >/dev/null 2>&1; then
		sha256="$(openssl dgst -sha256 "${source}" | awk '{print $NF}')"
	fi

	die "no compatible source-IPset patch found (mwan3_version=${mwan3_version:-unknown} sha256=${sha256:-unknown})"
fi

stagedir="$(new_temp_dir)"
[ -n "${stagedir}" ] || die "failed to create staging directory"
staged="${stagedir}/lib/mwan3/mwan3.sh"
# Kept beside ${dst} so the final install is a same-filesystem rename. Nothing
# in mwan3 globs /lib/mwan3; every file there is sourced by explicit path.
tmp_dst="${dst}.new.${pkg}"

stage_die() {
	rm -rf "${stagedir}" >/dev/null 2>&1 || true
	rm -f "${tmp_dst}" >/dev/null 2>&1 || true
	die "$*"
}

mkdir -p "${stagedir}/lib/mwan3"
cp -fp "${source}" "${staged}" || stage_die "failed to stage ${source}"

if ! apply_patch_in_dir "${stagedir}" "${chosen_base_patch}"; then
	stage_die "failed to stage patch $(basename "${chosen_base_patch}")"
fi

if select_patch "${staged}" "${local_patch_dir}"; then
	chosen_local_patch="${selected_patch}"
else
	stage_die "no compatible local-traffic patch found under ${local_patch_dir}"
fi

if ! apply_patch_in_dir "${stagedir}" "${chosen_local_patch}"; then
	stage_die "failed to stage patch $(basename "${chosen_local_patch}")"
fi

# Nothing to install when ${dst} already matches what these patches produce.
# Targets without cmp fall through and rewrite the file with identical content.
if cmp -s "${staged}" "${dst}" 2>/dev/null; then
	rm -rf "${stagedir}" >/dev/null 2>&1 || true
	exit 0
fi

echo "${pkg}: applying $(basename "${chosen_base_patch}") and $(basename "${chosen_local_patch}") for mwan3_version=${mwan3_version:-unknown}" >&2

if [ "${source}" != "${backup}" ]; then
	cp -fp "${source}" "${backup}" || stage_die "failed to back up ${dst}"
fi

# Write beside ${dst} and rename over it, so a failure part-way through the copy
# cannot leave a truncated mwan3.sh behind.
cp -fp "${staged}" "${tmp_dst}" || stage_die "failed to write ${tmp_dst}"
mv -f "${tmp_dst}" "${dst}" || stage_die "failed to install patched ${dst}"
rm -rf "${stagedir}" >/dev/null 2>&1 || true

if [ -z "${IPKG_INSTROOT:-}" ] && [ -x /etc/init.d/mwan3 ]; then
	/etc/init.d/mwan3 restart >/dev/null 2>&1 || true
fi

exit 0
