#!/bin/sh
set -eu

pkg="swanpan-mwan3-patch"

# When running on a live system, IPKG_INSTROOT is unset.
# Use / as the logical root in that case.
root="${IPKG_INSTROOT:-/}"

dst="${root}/lib/mwan3/mwan3.sh"
backup="${root}/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch"
tmp_dst="${dst}.new.${pkg}"
patch_dir="${root}/usr/share/swanpan-mwan3-patch/patches"

die() {
	echo "${pkg}: $*" >&2
	exit 1
}

if [ ! -f "${dst}" ]; then
	echo "${pkg}: ${dst} not found; skipping" >&2
	exit 0
fi

# This package only patches a stock mwan3.sh. It never rewrites a file that an
# earlier release already patched, because the shipped patches change between
# releases and nothing in the file says which one wrote it. Remove the package
# (postrm restores the backup) and install it again to pick up a newer patch.
if grep -q "\bipset_src\b" "${dst}"; then
	echo "${pkg}: ${dst} is already patched; remove this package and install it again to re-patch" >&2
	exit 0
fi

command -v patch >/dev/null 2>&1 || die "patch command not found (install package 'patch')"

tmpbase="${root}/tmp"
mkdir -p "${tmpbase}" 2>/dev/null || true
tmpdir="$(mktemp -d "${tmpbase}/${pkg}.XXXXXX")" || die "failed to create temp dir"
trap 'rm -rf "${tmpdir}"; rm -f "${tmp_dst}"' EXIT HUP INT TERM

staged="${tmpdir}/lib/mwan3/mwan3.sh"
mkdir -p "${tmpdir}/lib/mwan3"

# Selection is content-based: the first patch that applies cleanly to a copy of
# the installed file wins, and that copy is what gets installed. Patches target
# the relative path lib/mwan3/mwan3.sh, hence -p0.
selected=""
for candidate in "${patch_dir}"/*.patch; do
	[ -f "${candidate}" ] || continue

	cp -fp "${dst}" "${staged}"
	if (cd "${tmpdir}" && patch -p0 < "${candidate}" >/dev/null 2>&1); then
		selected="${candidate}"
		break
	fi
done

if [ -z "${selected}" ]; then
	sha256=""
	if command -v sha256sum >/dev/null 2>&1; then
		sha256="$(sha256sum "${dst}" | awk '{print $1}')"
	elif command -v openssl >/dev/null 2>&1; then
		sha256="$(openssl dgst -sha256 "${dst}" | awk '{print $NF}')"
	fi

	die "no compatible patch found (sha256=${sha256:-unknown})"
fi

echo "${pkg}: applying $(basename "${selected}")" >&2

cp -fp "${dst}" "${backup}" || die "failed to back up ${dst}"

# Write beside ${dst} and rename over it, so a failure part-way through the copy
# cannot leave a truncated mwan3.sh behind.
cp -fp "${staged}" "${tmp_dst}" || die "failed to write ${tmp_dst}"
mv -f "${tmp_dst}" "${dst}" || die "failed to install patched ${dst}"

if [ -z "${IPKG_INSTROOT:-}" ] && [ -x /etc/init.d/mwan3 ]; then
	/etc/init.d/mwan3 restart >/dev/null 2>&1 || true
fi

exit 0
