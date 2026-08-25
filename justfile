set shell := ["sh", "-eu", "-c"]

output_root := "dist"
cache_root := "dist/.cache"

default:
    @just --list

# GL.iNet GL-MT3600BE Beryl 7 (mediatek/filogic, aarch64_cortex-a53).
MT3600BE version="25.12.5":
    ./scripts/build-sdk.sh \
        --openwrt-version "{{ version }}" \
        --sdk-image "openwrt/sdk:mediatek-filogic-{{ version }}" \
        --platform linux/amd64 \
        --cache-dir "{{ cache_root }}" \
        --package swanpan-usb-wan-name \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
        --package swanpan-chinadns-ng \
        --package swanpan-mwan3-patch \
        --package swanpan-luci-app-mwan3-patch \
        --output "{{ output_root }}/MT3600BE/{{ version }}"

# GL.iNet GL-MT3000 Beryl AX (mediatek/filogic, aarch64_cortex-a53).
MT3000 version="25.12.5":
    ./scripts/build-sdk.sh \
        --openwrt-version "{{ version }}" \
        --sdk-image "openwrt/sdk:mediatek-filogic-{{ version }}" \
        --platform linux/amd64 \
        --cache-dir "{{ cache_root }}" \
        --package swanpan-usb-wan-name \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
        --package swanpan-chinadns-ng \
        --package swanpan-mwan3-patch \
        --package swanpan-luci-app-mwan3-patch \
        --output "{{ output_root }}/MT3000/{{ version }}"

# GL.iNet GL-MT2500 Brume 2 (mediatek/filogic, aarch64_cortex-a53).
MT2500 version="25.12.5":
    ./scripts/build-sdk.sh \
        --openwrt-version "{{ version }}" \
        --sdk-image "openwrt/sdk:mediatek-filogic-{{ version }}" \
        --platform linux/amd64 \
        --cache-dir "{{ cache_root }}" \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
        --package swanpan-chinadns-ng \
        --package swanpan-mwan3-patch \
        --package swanpan-luci-app-mwan3-patch \
        --output "{{ output_root }}/MT2500/{{ version }}"

# GL.iNet GL-XE300 Puli (vendor firmware 4.3.27, Native OpenWrt 22.03.4).
XE300 version="22.03.4":
    ./scripts/build-sdk.sh \
        --openwrt-version "{{ version }}" \
        --sdk-image "openwrt/sdk:ath79-nand-{{ version }}" \
        --platform linux/amd64 \
        --cache-dir "{{ cache_root }}" \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
        --output "{{ output_root }}/XE300/vendor-4.3.27"

# GL.iNet GL-E5800 Mudi 7 (vendor firmware 4.8.5, QuecOpen/OpenWrt 23.05.4).
E5800 version="23.05.4":
    ./scripts/build-sdk.sh \
        --openwrt-version "{{ version }}" \
        --sdk-image "openwrt/sdk:mediatek-filogic-{{ version }}" \
        --platform linux/amd64 \
        --cache-dir "{{ cache_root }}" \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
        --output "{{ output_root }}/E5800/vendor-4.8.5"

# GL.iNet GL-BE3600 Slate 7 (vendor firmware 4.9.0, QSDK/OpenWrt 23.05).
BE3600 version="23.05.6":
    ./scripts/build-sdk.sh \
        --openwrt-version "{{ version }}" \
        --sdk-image "openwrt/sdk:mediatek-filogic-{{ version }}" \
        --platform linux/amd64 \
        --cache-dir "{{ cache_root }}" \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
        --output "{{ output_root }}/BE3600/vendor-4.9.0"

# Ubiquiti EdgeRouter X (ramips/mt7621, mipsel_24kc).
ERX version="25.12.5":
    ./scripts/build-sdk.sh \
        --openwrt-version "{{ version }}" \
        --sdk-image "openwrt/sdk:ramips-mt7621-{{ version }}" \
        --platform linux/amd64 \
        --cache-dir "{{ cache_root }}" \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
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
        --cache-dir "{{ cache_root }}" \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
        --package swanpan-chinadns-ng \
        --package swanpan-mwan3-patch \
        --package swanpan-luci-app-mwan3-patch \
        --output "{{ output_root }}/ER4/{{ version }}"

# Ubiquiti EdgeRouter Pro ERPro-8 (octeon/generic, mips64_octeonplus).
ERPRO version="25.12.5":
    ./scripts/build-sdk.sh \
        --openwrt-version "{{ version }}" \
        --sdk-image "openwrt/sdk:octeon-generic-{{ version }}" \
        --platform linux/amd64 \
        --cache-dir "{{ cache_root }}" \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
        --package swanpan-chinadns-ng \
        --package swanpan-mwan3-patch \
        --package swanpan-luci-app-mwan3-patch \
        --output "{{ output_root }}/ERPRO/{{ version }}"

# Ubiquiti EdgeRouter Lite (octeon/generic, mips64_octeonplus).
ERLITE version="25.12.5":
    ./scripts/build-sdk.sh \
        --openwrt-version "{{ version }}" \
        --sdk-image "openwrt/sdk:octeon-generic-{{ version }}" \
        --platform linux/amd64 \
        --cache-dir "{{ cache_root }}" \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
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
        --cache-dir "{{ cache_root }}" \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
        --package swanpan-chinadns-ng \
        --package swanpan-mwan3-patch \
        --package swanpan-luci-app-mwan3-patch \
        --output "{{ output_root }}/USG/{{ version }}"

# Generic x86/64 (x86/64, x86_64).
X86_64 version="25.12.5":
    ./scripts/build-sdk.sh \
        --openwrt-version "{{ version }}" \
        --sdk-image "openwrt/sdk:x86-64-{{ version }}" \
        --platform linux/amd64 \
        --cache-dir "{{ cache_root }}" \
        --package swanpan-chnroute \
        --package swanpan-netseed \
        --package swanpan-dldns \
        --package swanpan-chinadns-ng \
        --package swanpan-mwan3-patch \
        --package swanpan-luci-app-mwan3-patch \
        --output "{{ output_root }}/X86_64/{{ version }}"

# Build every default device recipe sequentially so shared SDK caches are reused.
ALL:
    just MT3600BE
    just MT3000
    just MT2500
    just XE300
    just E5800
    just BE3600
    just ERX
    just ER4
    just ERPRO
    just ERLITE
    just USG
    just X86_64
