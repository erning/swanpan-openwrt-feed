#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)
TEST_ROOT=$(mktemp -d)

cleanup() {
	rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT HUP INT TERM

FAKE_BIN="$TEST_ROOT/bin"
CACHE_DIR="$TEST_ROOT/cache"
COUNT_FILE="$TEST_ROOT/docker-run-count"
mkdir -p "$FAKE_BIN"
printf '0\n' > "$COUNT_FILE"

cat > "$FAKE_BIN/docker" <<'EOF'
#!/bin/sh

set -eu

case "${1:-}" in
	info)
		exit 0
		;;
	image)
		[ "${2:-}" = inspect ] || exit 1
		case " $* " in
			*' --format '*) printf '%s\n' 'sha256:fake-sdk-image' ;;
		esac
		exit 0
		;;
	pull)
		exit 0
		;;
	run)
		shift
		output_dir=
		output_packages=
		download_cache_seen=0
		while [ "$#" -gt 0 ]; do
			case "$1" in
				-e)
					case "$2" in
						OUTPUT_PACKAGES=*) output_packages=${2#OUTPUT_PACKAGES=} ;;
					esac
					shift 2
					;;
				-v)
					case "$2" in
						*:/output) output_dir=${2%:/output} ;;
						*:/builder/dl) download_cache_seen=1 ;;
					esac
					shift 2
					;;
				--platform|--pull)
					shift 2
					;;
				--rm)
					shift
					;;
				*)
					shift
					;;
			esac
		done

		[ -n "$output_dir" ] || exit 1
		[ -n "$output_packages" ] || exit 1
		[ "$download_cache_seen" -eq "${FAKE_EXPECT_DOWNLOAD_CACHE:-0}" ] ||
			exit 1

		run_count=$(sed -n '1p' "$FAKE_DOCKER_COUNT")
		run_count=$((run_count + 1))
		printf '%s\n' "$run_count" > "$FAKE_DOCKER_COUNT"
		for package in $output_packages; do
			printf 'archive for %s\n' "$package" > \
				"$output_dir/$package-1.0.0-r1.apk"
		done
		printf '%s\n' 'mediatek/filogic' > "$output_dir/sdk.target"
		exit 0
		;;
esac

exit 1
EOF
chmod +x "$FAKE_BIN/docker"

run_build() {
	build_output=$1
	shift
	PATH="$FAKE_BIN:$PATH" \
	FAKE_DOCKER_COUNT="$COUNT_FILE" \
	FAKE_EXPECT_DOWNLOAD_CACHE=1 \
		"$REPO_ROOT/scripts/build-sdk.sh" \
		--openwrt-version 25.12.5 \
		--sdk-image openwrt/sdk:mediatek-filogic-25.12.5 \
		--platform linux/amd64 \
		--cache-dir "$CACHE_DIR" \
		--output "$build_output" \
		"$@"
}

FULL_OUTPUT="$TEST_ROOT/full"
run_build "$FULL_OUTPUT" --package swanpan-chinadns-ng
[ "$(sed -n '1p' "$COUNT_FILE")" -eq 1 ]
[ -f "$FULL_OUTPUT/swanpan-chinadns-ng-1.0.0-r1.apk" ]
[ -f "$FULL_OUTPUT/swanpan-chnroute-1.0.0-r1.apk" ]
grep -Fqx 'CACHE_HIT=0' "$FULL_OUTPUT/build.env"

SUBSET_OUTPUT="$TEST_ROOT/subset"
run_build "$SUBSET_OUTPUT" --package swanpan-chnroute
[ "$(sed -n '1p' "$COUNT_FILE")" -eq 1 ]
[ -f "$SUBSET_OUTPUT/swanpan-chnroute-1.0.0-r1.apk" ]
[ ! -e "$SUBSET_OUTPUT/swanpan-chinadns-ng-1.0.0-r1.apk" ]
grep -Fqx 'CACHE_HIT=1' "$SUBSET_OUTPUT/build.env"

cached_archive=$(find "$CACHE_DIR/artifacts" -type f \
	-name 'swanpan-chnroute-*.apk' -print | sed -n '1p')
[ -n "$cached_archive" ]
printf 'corrupt\n' >> "$cached_archive"

RECOVERED_OUTPUT="$TEST_ROOT/recovered"
run_build "$RECOVERED_OUTPUT" --package swanpan-chnroute
[ "$(sed -n '1p' "$COUNT_FILE")" -eq 2 ]
grep -Fqx 'CACHE_HIT=0' "$RECOVERED_OUTPUT/build.env"

HIT_OUTPUT="$TEST_ROOT/hit"
run_build "$HIT_OUTPUT" --package swanpan-chnroute
[ "$(sed -n '1p' "$COUNT_FILE")" -eq 2 ]
grep -Fqx 'CACHE_HIT=1' "$HIT_OUTPUT/build.env"

REBUILT_OUTPUT="$TEST_ROOT/rebuilt"
run_build "$REBUILT_OUTPUT" --package swanpan-chnroute --rebuild
[ "$(sed -n '1p' "$COUNT_FILE")" -eq 3 ]
grep -Fqx 'CACHE_HIT=0' "$REBUILT_OUTPUT/build.env"

UNCACHED_OUTPUT="$TEST_ROOT/uncached"
PATH="$FAKE_BIN:$PATH" \
FAKE_DOCKER_COUNT="$COUNT_FILE" \
FAKE_EXPECT_DOWNLOAD_CACHE=0 \
	"$REPO_ROOT/scripts/build-sdk.sh" \
	--openwrt-version 25.12.5 \
	--sdk-image openwrt/sdk:mediatek-filogic-25.12.5 \
	--platform linux/amd64 \
	--package swanpan-chnroute \
	--output "$UNCACHED_OUTPUT"
[ "$(sed -n '1p' "$COUNT_FILE")" -eq 4 ]
grep -Fqx 'CACHE_KEY=' "$UNCACHED_OUTPUT/build.env"
grep -Fqx 'CACHE_HIT=0' "$UNCACHED_OUTPUT/build.env"

printf '%s\n' 'build SDK cache tests passed'
