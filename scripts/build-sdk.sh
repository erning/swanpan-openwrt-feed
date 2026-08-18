#!/bin/sh

set -eu
set -f

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Build Swanpan packages with an official OpenWrt SDK container.

Usage:
  scripts/build-sdk.sh [options]

Required options (or matching environment variables):
  --openwrt-version VERSION  OpenWrt release
  --sdk-image IMAGE          SDK image
  --package NAME             Package to build; repeat for multiple packages
  --output DIR               Artifact directory

Optional settings:
  --jobs N                   Parallel make jobs
  --platform PLATFORM        Container platform
  --pull POLICY              Docker pull policy: always, missing, or never
  -h, --help                 Show this help

The same settings can be supplied with OPENWRT_VERSION, SDK_IMAGE,
PACKAGES, OUTPUT_DIR, JOBS, SDK_PLATFORM, and PULL_POLICY.
EOF
}

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)

openwrt_version=${OPENWRT_VERSION:-}
sdk_image=${SDK_IMAGE:-}
packages=${PACKAGES:-}
output_dir=${OUTPUT_DIR:-}
jobs=${JOBS:-}
sdk_platform=${SDK_PLATFORM:-}
pull_policy=${PULL_POLICY:-}
package_option_seen=0

while [ "$#" -gt 0 ]; do
	case "$1" in
		--openwrt-version)
			[ "$#" -ge 2 ] || die "$1 requires a value"
			openwrt_version=$2
			shift 2
			;;
		--sdk-image)
			[ "$#" -ge 2 ] || die "$1 requires a value"
			sdk_image=$2
			shift 2
			;;
		--package)
			[ "$#" -ge 2 ] || die "$1 requires a value"
			if [ "$package_option_seen" -eq 0 ]; then
				packages=
				package_option_seen=1
			fi
			packages="${packages:+$packages }$2"
			shift 2
			;;
		--output)
			[ "$#" -ge 2 ] || die "$1 requires a value"
			output_dir=$2
			shift 2
			;;
		--jobs)
			[ "$#" -ge 2 ] || die "$1 requires a value"
			jobs=$2
			shift 2
			;;
		--platform)
			[ "$#" -ge 2 ] || die "$1 requires a value"
			sdk_platform=$2
			shift 2
			;;
		--pull)
			[ "$#" -ge 2 ] || die "$1 requires a value"
			pull_policy=$2
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			die "unknown option: $1"
			;;
	esac
done

[ -n "$openwrt_version" ] || die "OPENWRT_VERSION or --openwrt-version is required"
[ -n "$sdk_image" ] || die "SDK_IMAGE or --sdk-image is required"
[ -n "$packages" ] || die "PACKAGES or at least one --package is required"
[ -n "$output_dir" ] || die "OUTPUT_DIR or --output is required"

case "$openwrt_version" in
	''|*[!0-9.]*|.*|*.)
		die "invalid OpenWrt version: $openwrt_version"
		;;
esac

case "$sdk_image" in
	openwrt/sdk:*|docker.io/openwrt/sdk:*)
		case "$sdk_image" in
			*-"$openwrt_version") ;;
			*) die "SDK image tag does not match OpenWrt $openwrt_version" ;;
		esac
		;;
esac

if [ -n "$jobs" ]; then
	case "$jobs" in
		*[!0-9]*) die "JOBS must be a positive integer" ;;
	esac
	[ "$jobs" -gt 0 ] || die "JOBS must be greater than zero"
fi

if [ -n "$pull_policy" ]; then
	case "$pull_policy" in
		always|missing|never) ;;
		*) die "PULL_POLICY must be always, missing, or never" ;;
	esac
fi

resolved_packages=
for requested_package in $packages; do
	case "$requested_package" in
		''|*[!A-Za-z0-9+_.-]*)
			die "invalid package name: $requested_package"
			;;
	esac

	if [ -f "$REPO_ROOT/$requested_package/Makefile" ]; then
		package=$requested_package
	elif [ -f "$REPO_ROOT/swanpan-$requested_package/Makefile" ]; then
		package="swanpan-$requested_package"
		printf 'Resolving %s to %s\n' "$requested_package" "$package"
	else
		die "package directory not found: $requested_package"
	fi

	case " $resolved_packages " in
		*" $package "*) ;;
		*) resolved_packages="${resolved_packages:+$resolved_packages }$package" ;;
	esac
done

command -v docker >/dev/null 2>&1 || die "docker is not installed"
docker info >/dev/null 2>&1 || die "the Docker daemon is not available"

mkdir -p "$output_dir"
output_dir=$(CDPATH='' cd -- "$output_dir" && pwd -P)
case "$output_dir" in
	/|"$REPO_ROOT") die "refusing to use a broad output directory: $output_dir" ;;
esac
if [ -n "${HOME:-}" ]; then
	user_home=$(CDPATH='' cd -- "$HOME" && pwd -P)
	[ "$output_dir" != "$user_home" ] ||
		die "refusing to use the home directory as output"
fi
incoming_dir=$(mktemp -d "$output_dir/.incoming.XXXXXX")
chmod 0777 "$incoming_dir"

cleanup() {
	if [ -d "$incoming_dir" ]; then
		rm -rf -- "$incoming_dir"
	fi
}
trap cleanup EXIT HUP INT TERM

source_commit=$(git -C "$REPO_ROOT" rev-parse --verify HEAD 2>/dev/null) ||
	die "unable to determine the source commit"
source_dirty=0
if ! git -C "$REPO_ROOT" diff --quiet --ignore-submodules -- 2>/dev/null ||
	! git -C "$REPO_ROOT" diff --cached --quiet --ignore-submodules -- 2>/dev/null ||
	[ -n "$(git -C "$REPO_ROOT" ls-files --others --exclude-standard 2>/dev/null)" ]; then
	source_dirty=1
fi

printf 'OpenWrt: %s\nSDK image: %s\nPackages: %s\nOutput: %s\n' \
	"$openwrt_version" "$sdk_image" "$resolved_packages" "$output_dir"

set -- docker run --rm
[ -z "$sdk_platform" ] || set -- "$@" --platform "$sdk_platform"
[ -z "$pull_policy" ] || set -- "$@" --pull "$pull_policy"
# The single-quoted script is evaluated by /bin/sh inside the container.
# shellcheck disable=SC2016
set -- "$@" \
	-e "EXPECTED_OPENWRT_VERSION=$openwrt_version" \
	-e "BUILD_SDK_IMAGE=$sdk_image" \
	-e "BUILD_SDK_PLATFORM=$sdk_platform" \
	-e "REQUESTED_PACKAGES=$resolved_packages" \
	-e "BUILD_JOBS=$jobs" \
	-e "SOURCE_COMMIT=$source_commit" \
	-e "SOURCE_DIRTY=$source_dirty" \
	-v "$REPO_ROOT:/feed:ro" \
	-v "$incoming_dir:/output" \
	"$sdk_image" /bin/sh -eu -c '
		cd /builder

		[ -n "${VERSION_PATH:-}" ] || {
			echo "error: SDK image does not declare VERSION_PATH" >&2
			exit 1
		}
		[ -n "${TARGET:-}" ] || {
			echo "error: SDK image does not declare TARGET" >&2
			exit 1
		}

		case "$VERSION_PATH" in
			"releases/$EXPECTED_OPENWRT_VERSION") ;;
			*)
				echo "error: SDK release $VERSION_PATH does not match $EXPECTED_OPENWRT_VERSION" >&2
				exit 1
				;;
		esac

		cp feeds.conf.default feeds.conf
		sed -i "/^[[:space:]]*src-[^[:space:]]*[[:space:]][[:space:]]*swanpan[[:space:]]/d" feeds.conf
		printf "src-link swanpan /feed\n" >> feeds.conf
		./scripts/feeds update swanpan
		./scripts/feeds install -a -p swanpan
		make defconfig

		for package in $REQUESTED_PACKAGES; do
			echo "==> Building $package"
			if [ -n "$BUILD_JOBS" ]; then
				make -j"$BUILD_JOBS" "package/feeds/swanpan/$package/compile" V=s
			else
				make "package/feeds/swanpan/$package/compile" V=s
			fi
		done

		for package in $REQUESTED_PACKAGES; do
			artifacts=$(find bin/packages -type f \
				-path "*/swanpan/$package-*.apk" -print)
			[ -n "$artifacts" ] || {
				echo "error: no APK produced for $package" >&2
				exit 1
			}
		done

		artifacts=$(find bin/packages -type f -path "*/swanpan/*.apk" -print)
		for artifact in $artifacts; do
			cp -f "$artifact" /output/
		done

		{
			printf "OPENWRT_VERSION=%s\n" "$EXPECTED_OPENWRT_VERSION"
			printf "SDK_IMAGE=%s\n" "$BUILD_SDK_IMAGE"
			printf "SDK_PLATFORM=%s\n" "$BUILD_SDK_PLATFORM"
			printf "SDK_TARGET=%s\n" "$TARGET"
			printf "PACKAGES=\"%s\"\n" "$REQUESTED_PACKAGES"
			printf "JOBS=%s\n" "$BUILD_JOBS"
			printf "SOURCE_COMMIT=%s\n" "$SOURCE_COMMIT"
			printf "SOURCE_DIRTY=%s\n" "$SOURCE_DIRTY"
		} > /output/build.env
	'
"$@"

artifacts=$(find "$incoming_dir" -maxdepth 1 -type f -name '*.apk' -print)
[ -n "$artifacts" ] || die "the SDK build produced no APK files"

find "$output_dir" -maxdepth 1 -type f -name 'swanpan-*.apk' \
	-exec rm -f -- {} +
for artifact in $artifacts; do
	mv -f "$artifact" "$output_dir/"
done
mv -f "$incoming_dir/build.env" "$output_dir/build.env"
rmdir "$incoming_dir"
trap - EXIT HUP INT TERM

printf 'Build complete:\n'
for artifact in $artifacts; do
	printf '  %s/%s\n' "$output_dir" "$(basename "$artifact")"
done
