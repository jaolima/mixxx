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

UNSIGNED_APK="build/android-build/build/outputs/apk/release/android-build-release-unsigned.apk"

# -c compares checksums instead of modification times. Files arriving from
# another filesystem carry different timestamps, and without this every build
# would recompile the whole tree.
#
# packaging/ matters as much as the others: it is the Android package source
# directory (QT_ANDROID_PACKAGE_SOURCE_DIR), so the manifest and any Java class
# live there. Leaving it out means a new Java file never reaches the APK while
# the build still reports success.
rsync -rc --delete "$SRC/src/" src/
rsync -rc --delete "$SRC/res/" res/
rsync -rc --delete "$SRC/packaging/" packaging/
rsync -rc "$SRC/CMakeLists.txt" CMakeLists.txt

# set +u around the sourcing, and stderr kept: android_buildenv.sh tests
# ${GITHUB_ENV} unguarded, so "nounset" aborts inside it - and an abort inside a
# sourced file kills this script too. Silencing stderr on top of that produced
# the worst possible failure: no output, exit status 0, and the previous APK
# still sitting on disk, which reads exactly like success.
set +u
# shellcheck source=/dev/null
source tools/android_buildenv.sh setup > /dev/null
set -u

# The Gradle step reuses cached assets: a changed QML file under res/ can
# otherwise ship as its previous version, with the build reporting success.
rm -rf build/android-build

cmake --build build -j"$(nproc)"

# Refuse to sign an APK the build did not just produce. Without this check a
# silent failure upstream leaves the old file in place and the install looks
# like it worked.
if [ ! -f "$UNSIGNED_APK" ]; then
    echo "Build produced no APK: $UNSIGNED_APK" >&2
    exit 1
fi

BUILD_TOOLS="$(ls -d /usr/lib/android-sdk/build-tools/* | tail -1)"

"$BUILD_TOOLS/zipalign" -f -p 4 "$UNSIGNED_APK" /tmp/mixxx-aligned.apk
"$BUILD_TOOLS/apksigner" sign \
    --ks "$KEYSTORE" \
    --ks-pass "pass:$KEYSTORE_PASS" \
    --key-pass "pass:$KEYSTORE_PASS" \
    --out "$OUT" \
    /tmp/mixxx-aligned.apk
rm -f /tmp/mixxx-aligned.apk

echo "BUILD_OK $OUT"
