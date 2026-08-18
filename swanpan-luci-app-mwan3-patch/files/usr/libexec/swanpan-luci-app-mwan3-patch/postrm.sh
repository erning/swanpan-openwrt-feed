#!/bin/sh
set -eu

root="${IPKG_INSTROOT:-}"

pkg="swanpan-luci-app-mwan3-patch"

dst_js="${root}/www/luci-static/resources/view/mwan3/network/rule.js"
dst_gz="${dst_js}.gz"
dst_lua="${root}/usr/lib/lua/luci/model/cbi/mwan/ruleconfig.lua"

backup_js="${dst_js}.orig.${pkg}"
backup_gz="${dst_gz}.orig.${pkg}"
backup_lua="${dst_lua}.orig.${pkg}"

if [ -f "${backup_js}" ]; then
	mv -f "${backup_js}" "${dst_js}"
	chmod 0644 "${dst_js}" || true
fi

if [ -f "${backup_gz}" ]; then
	mv -f "${backup_gz}" "${dst_gz}"
	chmod 0644 "${dst_gz}" || true
fi

if [ -f "${backup_lua}" ]; then
	mv -f "${backup_lua}" "${dst_lua}"
	chmod 0644 "${dst_lua}" || true
fi

exit 0
