set shell := ["sh", "-eu", "-c"]

dist := "dist"
default_version := "25.12.5"

default:
    @just --list

# GL.iNet GL-MT3600BE (mediatek/filogic, aarch64_cortex-a53).
MT3600BE version=default_version: (_build-target "MT3600BE" "mediatek" "filogic" version)

# GL.iNet GL-MT3000 (mediatek/filogic, aarch64_cortex-a53).
MT3000 version=default_version: (_build-target "MT3000" "mediatek" "filogic" version)

# GL.iNet GL-MT2500 (mediatek/filogic, aarch64_cortex-a53).
MT2500 version=default_version: (_build-target "MT2500" "mediatek" "filogic" version)

# GL.iNet GL-XE300 (ath79/nand, mips_24kc).
XE300 version=default_version: (_build-target "XE300" "ath79" "nand" version)

# Ubiquiti EdgeRouter X (ramips/mt7621, mipsel_24kc).
ERX version=default_version: (_build-target "ERX" "ramips" "mt7621" version)

# Ubiquiti EdgeRouter 4 (octeon/generic, mips64_octeonplus).
ER4 version=default_version: (_build-target "ER4" "octeon" "generic" version)

# Ubiquiti EdgeRouter Lite (octeon/generic, mips64_octeonplus).
ERLITE version=default_version: (_build-target "ERLITE" "octeon" "generic" version)

# Ubiquiti UniFi Security Gateway (octeon/generic, mips64_octeonplus).
USG version=default_version: (_build-target "USG" "octeon" "generic" version)

[private]
_build-target device target subtarget version:
    ./scripts/build-sdk.sh \
    	--openwrt-version "{{ version }}" \
    	--sdk-image "openwrt/sdk:{{ target }}-{{ subtarget }}-{{ version }}" \
    	--platform linux/amd64 \
    	--package swanpan-usb-wan-name \
    	--package swanpan-chnroute \
    	--package swanpan-chinadns-ng \
    	--package swanpan-mwan3-patch \
    	--package swanpan-luci-app-mwan3-patch \
    	--output "{{ dist }}/{{ device }}/{{ version }}"
