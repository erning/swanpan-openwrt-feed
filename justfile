set shell := ["sh", "-eu", "-c"]

output_root := "dist"

default:
    @just --list

# GL.iNet GL-MT3600BE (mediatek/filogic, aarch64_cortex-a53).
MT3600BE version="25.12.5":
    ./scripts/build-sdk.sh \
    	--openwrt-version "{{ version }}" \
    	--sdk-image "openwrt/sdk:mediatek-filogic-{{ version }}" \
    	--platform linux/amd64 \
    	--package swanpan-usb-wan-name \
    	--package swanpan-chnroute \
    	--package swanpan-chinadns-ng \
    	--package swanpan-mwan3-patch \
    	--package swanpan-luci-app-mwan3-patch \
    	--output "{{ output_root }}/MT3600BE/{{ version }}"

# GL.iNet GL-MT3000 (mediatek/filogic, aarch64_cortex-a53).
MT3000 version="25.12.5":
    ./scripts/build-sdk.sh \
    	--openwrt-version "{{ version }}" \
    	--sdk-image "openwrt/sdk:mediatek-filogic-{{ version }}" \
    	--platform linux/amd64 \
    	--package swanpan-usb-wan-name \
    	--package swanpan-chnroute \
    	--package swanpan-chinadns-ng \
    	--package swanpan-mwan3-patch \
    	--package swanpan-luci-app-mwan3-patch \
    	--output "{{ output_root }}/MT3000/{{ version }}"

# GL.iNet GL-MT2500 (mediatek/filogic, aarch64_cortex-a53).
MT2500 version="25.12.5":
    ./scripts/build-sdk.sh \
    	--openwrt-version "{{ version }}" \
    	--sdk-image "openwrt/sdk:mediatek-filogic-{{ version }}" \
    	--platform linux/amd64 \
    	--package swanpan-usb-wan-name \
    	--package swanpan-chnroute \
    	--package swanpan-chinadns-ng \
    	--package swanpan-mwan3-patch \
    	--package swanpan-luci-app-mwan3-patch \
    	--output "{{ output_root }}/MT2500/{{ version }}"

# GL.iNet GL-XE300 (ath79/nand, mips_24kc).
XE300 version="25.12.5":
    ./scripts/build-sdk.sh \
    	--openwrt-version "{{ version }}" \
    	--sdk-image "openwrt/sdk:ath79-nand-{{ version }}" \
    	--platform linux/amd64 \
    	--package swanpan-usb-wan-name \
    	--package swanpan-chnroute \
    	--package swanpan-chinadns-ng \
    	--package swanpan-mwan3-patch \
    	--package swanpan-luci-app-mwan3-patch \
    	--output "{{ output_root }}/XE300/{{ version }}"

# Ubiquiti EdgeRouter X (ramips/mt7621, mipsel_24kc).
ERX version="25.12.5":
    ./scripts/build-sdk.sh \
    	--openwrt-version "{{ version }}" \
    	--sdk-image "openwrt/sdk:ramips-mt7621-{{ version }}" \
    	--platform linux/amd64 \
    	--package swanpan-chnroute \
    	--package swanpan-chinadns-ng \
    	--package swanpan-mwan3-patch \
    	--package swanpan-luci-app-mwan3-patch \
    	--output "{{ output_root }}/ERX/{{ version }}"

# Ubiquiti EdgeRouter 4 (octeon/generic, mips64_octeonplus).
ER4 version="25.12.5":
    ./scripts/build-sdk.sh \
    	--openwrt-version "{{ version }}" \
    	--sdk-image "openwrt/sdk:octeon-generic-{{ version }}" \
    	--platform linux/amd64 \
    	--package swanpan-chnroute \
    	--package swanpan-chinadns-ng \
    	--package swanpan-mwan3-patch \
    	--package swanpan-luci-app-mwan3-patch \
    	--output "{{ output_root }}/ER4/{{ version }}"

# Ubiquiti EdgeRouter Lite (octeon/generic, mips64_octeonplus).
ERLITE version="25.12.5":
    ./scripts/build-sdk.sh \
    	--openwrt-version "{{ version }}" \
    	--sdk-image "openwrt/sdk:octeon-generic-{{ version }}" \
    	--platform linux/amd64 \
    	--package swanpan-chnroute \
    	--package swanpan-chinadns-ng \
    	--package swanpan-mwan3-patch \
    	--package swanpan-luci-app-mwan3-patch \
    	--output "{{ output_root }}/ERLITE/{{ version }}"

# Ubiquiti UniFi Security Gateway (octeon/generic, mips64_octeonplus).
USG version="25.12.5":
    ./scripts/build-sdk.sh \
    	--openwrt-version "{{ version }}" \
    	--sdk-image "openwrt/sdk:octeon-generic-{{ version }}" \
    	--platform linux/amd64 \
    	--package swanpan-chnroute \
    	--package swanpan-chinadns-ng \
    	--package swanpan-mwan3-patch \
    	--package swanpan-luci-app-mwan3-patch \
    	--output "{{ output_root }}/USG/{{ version }}"
