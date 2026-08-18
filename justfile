set shell := ["sh", "-eu", "-c"]

dist := "dist"

default:
    @just --list

# Build all Swanpan packages for the GL-MT3600BE.
gl-mt3600be version="25.12.5": (_build-filogic "gl-mt3600be" version)

# Build all Swanpan packages for the GL-MT3000.
gl-mt3000 version="25.12.5": (_build-filogic "gl-mt3000" version)

# Build all Swanpan packages for the GL-MT2500.
gl-mt2500 version="25.12.5": (_build-filogic "gl-mt2500" version)

[private]
_build-filogic device version:
    ./scripts/build-sdk.sh \
    	--openwrt-version "{{ version }}" \
    	--sdk-image "openwrt/sdk:mediatek-filogic-{{ version }}" \
    	--platform linux/amd64 \
    	--package swanpan-usb-wan-name \
    	--package swanpan-chnroute \
    	--package swanpan-chinadns-ng \
    	--package swanpan-mwan3-patch \
    	--package swanpan-luci-app-mwan3-patch \
    	--output "{{ dist }}/{{ device }}/{{ version }}"
