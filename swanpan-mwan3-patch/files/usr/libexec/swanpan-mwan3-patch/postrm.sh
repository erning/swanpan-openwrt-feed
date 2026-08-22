#!/bin/sh
set -eu

root="${IPKG_INSTROOT:-}"

dst="${root}/lib/mwan3/mwan3.sh"
backup="${root}/lib/mwan3/mwan3.sh.orig.swanpan-mwan3-patch"

if [ -z "${IPKG_INSTROOT:-}" ]; then
	iptables -t mangle -D OUTPUT -j mwan3_output_hook >/dev/null 2>&1 || true
	ip6tables -t mangle -D OUTPUT -j mwan3_output_hook >/dev/null 2>&1 || true
fi

if [ -f "${backup}" ]; then
	mv -f "${backup}" "${dst}"
	chmod 0644 "${dst}" || true
fi

if [ -z "${IPKG_INSTROOT:-}" ] && [ -x /etc/init.d/mwan3 ]; then
	/etc/init.d/mwan3 restart >/dev/null 2>&1 || true
fi

exit 0
