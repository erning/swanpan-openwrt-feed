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

if grep -q "\bipset_src\b" "${dst}"; then
	exit 0
fi

chosen_patch=""
set -- "${patch_dir}"/*.patch
[ -e "${1}" ] || die "no patches installed under ${patch_dir}"

command -v patch >/dev/null 2>&1 || die "patch command not found (install package 'patch')"

for p in "${patch_dir}"/*.patch; do
	tmpbase="${root}/tmp"
	[ -z "${root}" ] && tmpbase="/tmp"
	mkdir -p "${tmpbase}" 2>/dev/null || true

	tmpdir="$(mktemp -d "${tmpbase}/${pkg}.XXXXXX" 2>/dev/null || true)"
	[ -n "${tmpdir}" ] || die "failed to create temp dir under ${tmpbase}"

	mkdir -p "${tmpdir}/lib/mwan3"
	cp -fp "${dst}" "${tmpdir}/lib/mwan3/mwan3.sh"

	if apply_patch_in_dir "${tmpdir}" "${p}"; then
		chosen_patch="${p}"
		rm -rf "${tmpdir}" >/dev/null 2>&1 || true
		break
	fi

	rm -rf "${tmpdir}" >/dev/null 2>&1 || true
done

if [ -z "${chosen_patch}" ]; then
	sha256=""
	if command -v sha256sum >/dev/null 2>&1; then
		sha256="$(sha256sum "${dst}" | awk '{print $1}')"
	elif command -v shasum >/dev/null 2>&1; then
		sha256="$(shasum -a 256 "${dst}" | awk '{print $1}')"
	elif command -v openssl >/dev/null 2>&1; then
		sha256="$(openssl dgst -sha256 "${dst}" | awk '{print $NF}')"
	fi

	die "no compatible patch found (mwan3_version=${mwan3_version:-unknown} sha256=${sha256:-unknown})"
fi

echo "${pkg}: applying $(basename "${chosen_patch}") for mwan3_version=${mwan3_version:-unknown}" >&2

cp -fp "${dst}" "${backup}" || die "failed to back up ${dst}"

if ! (
	cd "${root}"
	patch -p0 < "${chosen_patch}" >/dev/null 2>&1 || patch < "${chosen_patch}" >/dev/null 2>&1
); then
	[ -f "${backup}" ] && cp -fp "${backup}" "${dst}" || true
	die "failed to apply patch $(basename "${chosen_patch}")"
fi

if [ -z "${IPKG_INSTROOT:-}" ] && [ -x /etc/init.d/mwan3 ]; then
	/etc/init.d/mwan3 restart >/dev/null 2>&1 || true
fi

exit 0
