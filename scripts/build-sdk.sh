#!/bin/sh

set -eu
set -f

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

sha256_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	else
		shasum -a 256 "$1" | awk '{print $1}'
	fi
}

pull_sdk_image() {
	set -- docker pull
	[ -z "$sdk_platform" ] || set -- "$@" --platform "$sdk_platform"
	"$@" "$sdk_image"
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
  --cache-dir DIR            Cache downloads and package archives
  --jobs N                   Parallel make jobs
  --platform PLATFORM        Container platform
  --pull POLICY              Docker pull policy: always, missing, or never
  --rebuild                  Ignore cached archives and rebuild them
  -h, --help                 Show this help

The same settings can be supplied with OPENWRT_VERSION, SDK_IMAGE,
PACKAGES, OUTPUT_DIR, CACHE_DIR, JOBS, SDK_PLATFORM, and PULL_POLICY.
EOF
}

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)

openwrt_version=${OPENWRT_VERSION:-}
sdk_image=${SDK_IMAGE:-}
packages=${PACKAGES:-}
output_dir=${OUTPUT_DIR:-}
cache_dir=${CACHE_DIR:-}
jobs=${JOBS:-}
sdk_platform=${SDK_PLATFORM:-}
pull_policy=${PULL_POLICY:-}
package_option_seen=0
rebuild=0

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
		--cache-dir)
			[ "$#" -ge 2 ] || die "$1 requires a value"
			cache_dir=$2
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
		--rebuild)
			rebuild=1
			shift
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

sdk_target_hint=
case "$sdk_image" in
	openwrt/sdk:*|docker.io/openwrt/sdk:*)
		case "$sdk_image" in
			*-"$openwrt_version")
				sdk_target_hint=${sdk_image##*:}
				sdk_target_hint=${sdk_target_hint%"-$openwrt_version"}
				sdk_target_hint=$(printf '%s\n' "$sdk_target_hint" |
					sed 's|-|/|')
				;;
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

output_packages=$resolved_packages
while :; do
	dependency_added=0
	for package in $output_packages; do
		dependencies=$(sed -n \
			's/^[[:space:]]*DEPENDS:=[[:space:]]*//p' \
			"$REPO_ROOT/$package/Makefile")
		for dependency in $dependencies; do
			case "$dependency" in
			+swanpan-*) dependency=${dependency#+} ;;
			*) continue ;;
			esac

			[ -f "$REPO_ROOT/$dependency/Makefile" ] ||
				die "Swanpan dependency not found: $dependency"
			case " $output_packages " in
				*" $dependency "*) ;;
				*)
					output_packages="$output_packages $dependency"
					dependency_added=1
					;;
			esac
		done
	done
	[ "$dependency_added" -eq 1 ] || break
done

resolved_packages=$(for package in $resolved_packages; do
	printf '%s\n' "$package"
done | LC_ALL=C sort | awk '
	BEGIN { separator = "" }
	{ printf "%s%s", separator, $0; separator = " " }
	END { print "" }
')
output_packages=$(for package in $output_packages; do
	printf '%s\n' "$package"
done | LC_ALL=C sort | awk '
	BEGIN { separator = "" }
	{ printf "%s%s", separator, $0; separator = " " }
	END { print "" }
')

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

source_hash=$(
	git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard -- \
		'swanpan-*' 'scripts/build-sdk.sh' |
		LC_ALL=C sort |
		while IFS= read -r source_path; do
			[ -f "$REPO_ROOT/$source_path" ] || continue
			printf '%s  %s\n' \
				"$(git -C "$REPO_ROOT" hash-object "$source_path")" \
				"$source_path"
		done |
		git -C "$REPO_ROOT" hash-object --stdin
) || die "unable to hash the build sources"

[ "$rebuild" -eq 0 ] || [ -n "$cache_dir" ] ||
	die "--rebuild requires CACHE_DIR or --cache-dir"

sdk_image_id=
sdk_cache_key=
artifact_cache_dir=
download_cache_dir=
docker_pull_policy=$pull_policy
if [ -n "$cache_dir" ]; then
	command -v sha256sum >/dev/null 2>&1 ||
		command -v shasum >/dev/null 2>&1 ||
		die "sha256sum or shasum is required when caching"

	mkdir -p "$cache_dir"
	cache_dir=$(CDPATH='' cd -- "$cache_dir" && pwd -P)
	case "$cache_dir" in
		/|"$REPO_ROOT"|"$output_dir")
			die "refusing to use a broad cache directory: $cache_dir"
			;;
	esac

	case "$pull_policy" in
		always)
			pull_sdk_image
			;;
		never)
			docker image inspect "$sdk_image" >/dev/null 2>&1 ||
				die "SDK image is not available locally: $sdk_image"
			;;
		''|missing)
			if ! docker image inspect "$sdk_image" >/dev/null 2>&1; then
				pull_sdk_image
			fi
			;;
	esac

	sdk_image_id=$(docker image inspect --format '{{.Id}}' "$sdk_image") ||
		die "unable to inspect SDK image: $sdk_image"
	sdk_cache_key=$(printf '%s\n%s\n' "$sdk_image_id" "$sdk_platform" |
		git -C "$REPO_ROOT" hash-object --stdin)
	artifact_cache_dir="$cache_dir/artifacts/$sdk_cache_key/$source_hash"
	download_cache_dir="$cache_dir/downloads/$sdk_cache_key"
	mkdir -p "$artifact_cache_dir" "$download_cache_dir"
	chmod 0777 "$download_cache_dir"
	docker_pull_policy=never
fi

cache_package_valid() {
	cache_check_package=$1
	cache_check_dir="$artifact_cache_dir/$cache_check_package"
	[ -f "$cache_check_dir/cache.env" ] || return 1
	[ -s "$cache_check_dir/SHA256SUMS" ] || return 1
	grep -Fqx 'CACHE_VERSION=1' "$cache_check_dir/cache.env" || return 1
	grep -Fqx "SDK_IMAGE_ID=$sdk_image_id" "$cache_check_dir/cache.env" || return 1
	grep -Fqx "SOURCE_HASH=$source_hash" "$cache_check_dir/cache.env" || return 1
	grep -Fqx "PACKAGE=$cache_check_package" "$cache_check_dir/cache.env" || return 1
	[ "$(grep -c '^SDK_TARGET=' "$cache_check_dir/cache.env")" -eq 1 ] || return 1
	cache_check_target=$(sed -n 's/^SDK_TARGET=//p' "$cache_check_dir/cache.env")
	case "$cache_check_target" in
		''|*[!A-Za-z0-9_./-]*) return 1 ;;
	esac

	cache_check_artifacts=$(find "$cache_check_dir" -maxdepth 1 -type f \
		\( -name "$cache_check_package-*.apk" -o \
		-name "${cache_check_package}_*.ipk" \) -print)
	[ -n "$cache_check_artifacts" ] || return 1
	cache_artifact_count=$(printf '%s\n' "$cache_check_artifacts" |
		awk 'NF { count++ } END { print count + 0 }')
	cache_checksum_count=$(wc -l < "$cache_check_dir/SHA256SUMS")
	[ "$cache_artifact_count" -eq "$cache_checksum_count" ] || return 1

	while IFS=' ' read -r cache_expected cache_filename; do
		case "$cache_filename" in
			''|*/*|.|..) return 1 ;;
		esac
		case "$cache_filename" in
			"$cache_check_package"-*.apk|"$cache_check_package"_*.ipk) ;;
			*) return 1 ;;
		esac
		[ -f "$cache_check_dir/$cache_filename" ] || return 1
		cache_actual=$(sha256_file "$cache_check_dir/$cache_filename")
		[ "$cache_actual" = "$cache_expected" ] || return 1
	done < "$cache_check_dir/SHA256SUMS"
}

write_build_env() {
	build_env_target=$1
	build_env_cache_hit=$2
	{
		printf 'OPENWRT_VERSION=%s\n' "$openwrt_version"
		printf 'SDK_IMAGE=%s\n' "$sdk_image"
		printf 'SDK_IMAGE_ID=%s\n' "$sdk_image_id"
		printf 'SDK_PLATFORM=%s\n' "$sdk_platform"
		printf 'SDK_TARGET=%s\n' "$build_env_target"
		printf 'PACKAGES="%s"\n' "$resolved_packages"
		printf 'OUTPUT_PACKAGES="%s"\n' "$output_packages"
		printf 'JOBS=%s\n' "$jobs"
		printf 'SOURCE_COMMIT=%s\n' "$source_commit"
		printf 'SOURCE_DIRTY=%s\n' "$source_dirty"
		printf 'SOURCE_HASH=%s\n' "$source_hash"
		printf 'CACHE_KEY=%s\n' "${sdk_cache_key:+$sdk_cache_key/$source_hash}"
		printf 'CACHE_HIT=%s\n' "$build_env_cache_hit"
	} > "$incoming_dir/build.env"
}

store_cached_package() {
	cache_store_package=$1
	cache_store_dir="$artifact_cache_dir/$cache_store_package"
	cache_store_tmp=$(mktemp -d \
		"$artifact_cache_dir/.${cache_store_package}.XXXXXX")

	find "$incoming_dir" -maxdepth 1 -type f \
		\( -name "$cache_store_package-*.apk" -o \
		-name "${cache_store_package}_*.ipk" \) \
		-exec cp -f -- {} "$cache_store_tmp/" \;
	{
		printf 'CACHE_VERSION=1\n'
		printf 'SDK_IMAGE_ID=%s\n' "$sdk_image_id"
		printf 'SOURCE_HASH=%s\n' "$source_hash"
		printf 'PACKAGE=%s\n' "$cache_store_package"
		printf 'SDK_TARGET=%s\n' "$sdk_target"
	} > "$cache_store_tmp/cache.env"
	find "$cache_store_tmp" -maxdepth 1 -type f \
		\( -name "$cache_store_package-*.apk" -o \
		-name "${cache_store_package}_*.ipk" \) -print |
		LC_ALL=C sort |
		while IFS= read -r cache_store_artifact; do
			printf '%s  %s\n' \
				"$(sha256_file "$cache_store_artifact")" \
				"$(basename "$cache_store_artifact")"
		done > "$cache_store_tmp/SHA256SUMS"
	[ -s "$cache_store_tmp/SHA256SUMS" ] || {
		rm -rf -- "$cache_store_tmp"
		die "unable to cache package: $cache_store_package"
	}

	if [ "$rebuild" -eq 0 ] && cache_package_valid "$cache_store_package"; then
		rm -rf -- "$cache_store_tmp"
		return
	fi

	cache_store_old=
	if [ -e "$cache_store_dir" ]; then
		cache_store_old="$artifact_cache_dir/.old.${cache_store_package}.$$"
		mv "$cache_store_dir" "$cache_store_old"
	fi
	if ! mv "$cache_store_tmp" "$cache_store_dir"; then
		[ -z "$cache_store_old" ] || mv "$cache_store_old" "$cache_store_dir"
		rm -rf -- "$cache_store_tmp"
		die "unable to publish cached package: $cache_store_package"
	fi
	[ -z "$cache_store_old" ] || rm -rf -- "$cache_store_old"
}

printf 'OpenWrt: %s\nSDK image: %s\nPackages: %s\nOutput: %s\n' \
	"$openwrt_version" "$sdk_image" "$resolved_packages" "$output_dir"

cache_hit=0
sdk_target=
if [ -n "$artifact_cache_dir" ] && [ "$rebuild" -eq 0 ]; then
	cache_hit=1
	for package in $output_packages; do
		if ! cache_package_valid "$package"; then
			cache_hit=0
			break
		fi
	done

	if [ "$cache_hit" -eq 1 ]; then
		for package in $output_packages; do
			cache_package_dir="$artifact_cache_dir/$package"
			package_sdk_target=$(sed -n 's/^SDK_TARGET=//p' \
				"$cache_package_dir/cache.env")
			if [ -z "$sdk_target" ]; then
				sdk_target=$package_sdk_target
			elif [ "$sdk_target" != "$package_sdk_target" ]; then
				die "cache contains inconsistent SDK targets"
			fi
			find "$cache_package_dir" -maxdepth 1 -type f \
				\( -name "$package-*.apk" -o \
				-name "${package}_*.ipk" \) \
				-exec cp -f -- {} "$incoming_dir/" \;
		done
		write_build_env "$sdk_target" 1
		printf 'Cache hit: %s/%s\n' "$sdk_cache_key" "$source_hash"
	fi
fi

if [ "$cache_hit" -eq 0 ]; then
	set -- docker run --rm
	[ -z "$sdk_platform" ] || set -- "$@" --platform "$sdk_platform"
	[ -z "$docker_pull_policy" ] || set -- "$@" --pull "$docker_pull_policy"
	set -- "$@" \
		-e "EXPECTED_OPENWRT_VERSION=$openwrt_version" \
		-e "SDK_TARGET_HINT=$sdk_target_hint" \
		-e "OUTPUT_PACKAGES=$output_packages" \
		-e "BUILD_JOBS=$jobs" \
		-v "$REPO_ROOT:/feed:ro" \
		-v "$incoming_dir:/output"
	[ -z "$download_cache_dir" ] ||
		set -- "$@" -v "$download_cache_dir:/builder/dl"
	# The single-quoted script is evaluated by /bin/sh inside the container.
	# shellcheck disable=SC2016
	set -- "$@" "$sdk_image" /bin/sh -eu -c '
		cd /builder

		if [ -n "${VERSION_PATH:-}" ]; then
			case "$VERSION_PATH" in
			"releases/$EXPECTED_OPENWRT_VERSION") ;;
			*)
				echo "error: SDK release $VERSION_PATH does not match $EXPECTED_OPENWRT_VERSION" >&2
				exit 1
				;;
			esac
		else
			sdk_version=$(sed -n \
				"s|^VERSION_REPO:=.*releases/\\([^)]*\\))$|\\1|p" \
				include/version.mk)
			[ "$sdk_version" = "$EXPECTED_OPENWRT_VERSION" ] || {
				echo "error: SDK release $sdk_version does not match $EXPECTED_OPENWRT_VERSION" >&2
				exit 1
			}
		fi

		sdk_target=${TARGET:-$SDK_TARGET_HINT}
		[ -n "$sdk_target" ] || {
			echo "error: unable to determine the SDK target" >&2
			exit 1
		}

		cp feeds.conf.default feeds.conf
		sed -i "/^[[:space:]]*src-[^[:space:]]*[[:space:]][[:space:]]*swanpan[[:space:]]/d" feeds.conf
		printf "src-link swanpan /feed\n" >> feeds.conf
		./scripts/feeds update swanpan
		./scripts/feeds install -a -p swanpan
		make defconfig

		for package in $OUTPUT_PACKAGES; do
			echo "==> Building $package"
			if [ -n "$BUILD_JOBS" ]; then
				make -j"$BUILD_JOBS" "package/feeds/swanpan/$package/compile" V=s
			else
				make "package/feeds/swanpan/$package/compile" V=s
			fi
		done

		for package in $OUTPUT_PACKAGES; do
			artifacts=$(find bin/packages -type f \
				\( -path "*/swanpan/$package-*.apk" -o \
				-path "*/swanpan/${package}_*.ipk" \) -print)
			[ -n "$artifacts" ] || {
				echo "error: no package archive produced for $package" >&2
				exit 1
			}
		done

		for package in $OUTPUT_PACKAGES; do
			find bin/packages -type f \
				\( -path "*/swanpan/$package-*.apk" -o \
				-path "*/swanpan/${package}_*.ipk" \) \
				-exec cp -f {} /output/ \;
		done

		printf "%s\n" "$sdk_target" > /output/sdk.target
	'
	"$@"

	[ -f "$incoming_dir/sdk.target" ] || die "the SDK did not report its target"
	[ "$(wc -l < "$incoming_dir/sdk.target")" -eq 1 ] ||
		die "the SDK reported an invalid target"
	sdk_target=$(sed -n '1p' "$incoming_dir/sdk.target")
	case "$sdk_target" in
		''|*[!A-Za-z0-9_./-]*) die "the SDK reported an invalid target" ;;
	esac
	rm -f -- "$incoming_dir/sdk.target"

	if [ -z "$sdk_image_id" ]; then
		sdk_image_id=$(docker image inspect --format '{{.Id}}' "$sdk_image") ||
			die "unable to inspect SDK image: $sdk_image"
	fi
	write_build_env "$sdk_target" 0

	if [ -n "$artifact_cache_dir" ]; then
		for package in $output_packages; do
			store_cached_package "$package"
		done
	fi
fi

artifacts=$(find "$incoming_dir" -maxdepth 1 -type f \
	\( -name '*.apk' -o -name '*.ipk' \) -print)
[ -n "$artifacts" ] || die "the SDK build produced no package archives"

find "$output_dir" -maxdepth 1 -type f \
	\( -name 'swanpan-*.apk' -o -name 'swanpan-*.ipk' \) \
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
