set shell := ["sh", "-eu", "-c"]

dist := "dist"

default:
    @just --list

# Build all Swanpan packages for the GL-MT3600BE.
gl-mt3600be:
    ./scripts/build-sdk.sh \
    	--openwrt-version "25.12.5" \
    	--sdk-image "openwrt/sdk:mediatek-filogic-25.12.5" \
    	--platform linux/amd64 \
    	--package swanpan-usb-wan-name \
    	--package swanpan-chnroute \
    	--package swanpan-chinadns-ng \
    	--package swanpan-mwan3-patch \
    	--package swanpan-luci-app-mwan3-patch \
    	--output "{{ dist }}/gl-mt3600be/25.12.5"
