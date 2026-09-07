#!/usr/bin/env bash
#
# Builds and signs the Android APK from a source tree that lives outside the
# Linux filesystem - a Windows checkout reached through /mnt, say.
#
# Why the sync step exists: the cross-compilation must run from a Linux host and
# from a clone inside the Linux filesystem, so the sources have to be copied in
# first. Copying a hand-written list of files is what this script used to do,
# and it silently built stale C++ for three rounds: the build passed, the APK
# installed, and the defect under investigation stayed exactly the same. The
# whole tree is synced now, and by content rather than by timestamp, so ninja
# still rebuilds only what actually changed.
#
# Usage:
#   tools/android_build_apk.sh [SOURCE_DIR] [BUILD_CLONE] [OUTPUT_APK]
#
# Defaults assume the layout this fork is developed in.

set -euo pipefail

SRC="${1:-/mnt/d/workspace/Projects/mixxx}"
CLONE="${2:-$HOME/mixxx}"
OUT="${3:-/mnt/d/workspace/Projects/mixxx-android/mixxx-custom.apk}"
KEYSTORE="${ANDROID_KEYSTORE:-$HOME/mixxx-debug.keystore}"
KEYSTORE_PASS="${ANDROID_KEYSTORE_PASS:-mixxxdev}"

for path in "$SRC" "$CLONE"; do
    if [ ! -d "$path" ]; then
        echo "Not a directory: $path" >&2
        exit 1
    fi
done

cd "$CLONE"

# -c compares checksums instead of modification times. Files arriving from
# another filesystem carry different timestamps, and without this every build
# would recompile the whole tree.
rsync -rc --delete "$SRC/src/" src/
rsync -rc --delete "$SRC/res/" res/
rsync -rc "$SRC/CMakeLists.txt" CMakeLists.txt

# shellcheck source=/dev/null
source tools/android_buildenv.sh setup > /dev/null 2>&1

# The Gradle step reuses cached assets: a changed QML file under res/ can
# otherwise ship as its previous version, with the build reporting success.
rm -rf build/android-build

cmake --build build -j"$(nproc)"

BUILD_TOOLS="$(ls -d /usr/lib/android-sdk/build-tools/* | tail -1)"
UNSIGNED="build/android-build/build/outputs/apk/release/android-build-release-unsigned.apk"

"$BUILD_TOOLS/zipalign" -f -p 4 "$UNSIGNED" /tmp/mixxx-aligned.apk
"$BUILD_TOOLS/apksigner" sign \
    --ks "$KEYSTORE" \
    --ks-pass "pass:$KEYSTORE_PASS" \
    --key-pass "pass:$KEYSTORE_PASS" \
    --out "$OUT" \
    /tmp/mixxx-aligned.apk
rm -f /tmp/mixxx-aligned.apk

echo "BUILD_OK $OUT"
