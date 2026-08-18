#!/bin/sh
set -eu

root="${IPKG_INSTROOT:-}"
script="${root}/usr/libexec/swanpan-luci-app-mwan3-patch/apply-overlay.sh"

[ -x "${script}" ] || exit 0
"${script}"
exit 0
