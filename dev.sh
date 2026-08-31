#!/usr/bin/env bash
#
# dev.sh - Mixxx development helper for Linux.
#
# One entry point to install the build dependencies, configure, build, run and
# test a development build of Mixxx. Picks up Ninja, ccache and a fast linker
# when they are available, and keeps the dev build's settings and music library
# separate from a system-wide Mixxx install.
#
# Quick start:
#     ./dev.sh setup     # once, installs dependencies (needs sudo)
#     ./dev.sh run       # configure + build + launch
#
# See './dev.sh help' for all commands and environment variables.

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

: "${BUILD_DIR:=${REPO_DIR}/build}"
: "${BUILD_TYPE:=RelWithDebInfo}"
: "${SETTINGS_DIR:=${HOME}/.mixxx-dev}"
: "${JOBS:=$(nproc 2>/dev/null || echo 4)}"
: "${CMAKE_EXTRA_ARGS:=}"
: "${DRY_RUN:=0}"

# --------------------------------------------------------------- output ----

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
fi

info() { printf '%s==>%s %s\n' "${C_BLUE}${C_BOLD}" "$C_RESET" "$*"; }
ok()   { printf '%s ok %s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%sfail%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# Print a command, then run it - or only print it when DRY_RUN=1.
run() {
    printf '%s+%s' "$C_DIM" "$C_RESET"
    printf ' %q' "$@"
    printf '\n'
    if [[ "$DRY_RUN" == 1 ]]; then
        return 0
    fi
    "$@"
}

have() { command -v "$1" >/dev/null 2>&1; }

# ------------------------------------------------------------ detection ----

# Echo the tools/ script that installs build dependencies for this distro, and
# whether it expects a "setup" argument. Format: "<script> [argument]".
detect_buildenv() {
    local id='' id_like=''
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        id="$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")"
        # shellcheck disable=SC1091
        id_like="$(. /etc/os-release 2>/dev/null && printf '%s' "${ID_LIKE:-}")"
    fi
    case " ${id} ${id_like} " in
        *' debian '*|*' ubuntu '*)          echo "tools/debian_buildenv.sh setup" ;;
        *' fedora '*|*' rhel '*|*' centos '*) echo "tools/rpm_buildenv.sh setup" ;;
        *' arch '*)                          echo "tools/archlinux_buildenv.sh" ;;
        *) return 1 ;;
    esac
}

# The build directory is already configured, so the generator is fixed.
is_configured() { [[ -f "${BUILD_DIR}/CMakeCache.txt" ]]; }

# --------------------------------------------------------------- cmake -----

CMAKE_ARGS=()

build_cmake_args() {
    CMAKE_ARGS=(
        -S "$REPO_DIR"
        -B "$BUILD_DIR"
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
        # Feature flags mirror the "Ubuntu 24.04" job in
        # .github/workflows/build.yml, so a local build matches what CI checks.
        -DQT6=ON
        -DQML=ON
        -DBULK=ON
        -DFFMPEG=ON
        -DLOCALECOMPARE=ON
        -DMAD=ON
        -DMODPLUG=ON
        -DWAVPACK=ON
        -DINSTALL_USER_UDEV_RULES=OFF
    )

    # The generator can only be chosen on the first configure of a build dir.
    if ! is_configured; then
        if have ninja; then
            CMAKE_ARGS+=(-G Ninja)
        else
            warn "ninja not found; using the default generator (slower rebuilds)"
        fi
    fi

    if have ccache; then
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER_LAUNCHER=ccache
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
        )
    fi

    # mold/lld cut link times a lot on a codebase this size.
    local linker=''
    if have mold; then
        linker=mold
    elif have ld.lld; then
        linker=lld
    fi
    if [[ -n "$linker" ]]; then
        CMAKE_ARGS+=(
            "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=${linker}"
            "-DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=${linker}"
        )
    fi

    if [[ -n "$CMAKE_EXTRA_ARGS" ]]; then
        # Deliberate word splitting: this is a user-supplied list of flags.
        # shellcheck disable=SC2206
        CMAKE_ARGS+=($CMAKE_EXTRA_ARGS)
    fi
}

# The generator is fixed at the first configure, so a build directory created
# before Ninja was installed keeps using the slower one until it is recreated.
check_generator() {
    is_configured || return 0
    have ninja || return 0
    local gen
    gen="$(sed -n 's/^CMAKE_GENERATOR:INTERNAL=//p' "${BUILD_DIR}/CMakeCache.txt" 2>/dev/null)"
    if [[ -n "$gen" && "$gen" != "Ninja" ]]; then
        warn "${BUILD_DIR} was configured with '${gen}', but Ninja is installed now."
        warn "Run './dev.sh clean && ./dev.sh build' to switch and get fast rebuilds."
    fi
}

require_cmake() {
    # In dry-run the point is to inspect the command line, so do not insist on
    # a toolchain being installed yet.
    if [[ "$DRY_RUN" == 1 ]]; then
        return 0
    fi
    have cmake || die "cmake not found. Run './dev.sh setup' first."
}

# ------------------------------------------------------------- commands ----

cmd_setup() {
    local buildenv script arg
    if ! buildenv="$(detect_buildenv)"; then
        die "Unsupported distro. See https://github.com/mixxxdj/mixxx/wiki/Compiling%20on%20Linux"
    fi
    read -r script arg <<<"$buildenv"

    [[ -f "${REPO_DIR}/${script}" ]] || die "missing ${script} - are you in the Mixxx source tree?"

    info "Installing build dependencies via ${script} (asks for sudo)"
    if [[ -n "$arg" ]]; then
        run bash "${REPO_DIR}/${script}" "$arg"
    else
        run bash "${REPO_DIR}/${script}"
    fi

    install_extra_tools "$script"
    ok "dependencies installed"
}

# The upstream buildenv scripts install cmake and ccache but not Ninja, which is
# what makes incremental rebuilds fast. Add it here.
install_extra_tools() {
    local script="$1"
    if have ninja; then
        return 0
    fi
    info "Installing Ninja (missing from ${script##*/})"
    case "$script" in
        *debian_buildenv.sh)
            run sudo apt-get install -y --no-install-recommends ninja-build ;;
        *rpm_buildenv.sh)
            run sudo dnf install -y ninja-build ;;
        *archlinux_buildenv.sh)
            run sudo pacman -S --needed --noconfirm ninja ;;
        *)
            warn "install 'ninja' manually for faster rebuilds" ;;
    esac
}

cmd_configure() {
    require_cmake
    build_cmake_args
    info "Configuring ${BUILD_TYPE} build in ${BUILD_DIR}"
    run cmake "${CMAKE_ARGS[@]}"
    ok "configured"
}

cmd_build() {
    require_cmake
    is_configured || cmd_configure
    check_generator
    info "Building with ${JOBS} parallel jobs"
    run cmake --build "$BUILD_DIR" --parallel "$JOBS" "$@"
    ok "build finished: ${BUILD_DIR}/mixxx"
}

cmd_run() {
    cmd_build
    local bin="${BUILD_DIR}/mixxx"
    if [[ "$DRY_RUN" != 1 && ! -x "$bin" ]]; then
        die "no executable at ${bin}"
    fi
    run mkdir -p "$SETTINGS_DIR"
    info "Launching Mixxx in developer mode (settings: ${SETTINGS_DIR})"
    run "$bin" --developer --settings-path "$SETTINGS_DIR" "$@"
}

cmd_test() {
    cmd_build
    info "Running the test suite"
    run ctest --test-dir "$BUILD_DIR" --output-on-failure "$@"
}

cmd_clean() {
    case "$BUILD_DIR" in
        "${REPO_DIR}"/*) ;;
        *) die "refusing to delete ${BUILD_DIR}: it is outside ${REPO_DIR}" ;;
    esac
    if [[ ! -d "$BUILD_DIR" ]]; then
        ok "nothing to clean, ${BUILD_DIR} does not exist"
        return 0
    fi
    info "Removing ${BUILD_DIR}"
    run rm -rf -- "$BUILD_DIR"
    ok "clean"
}

cmd_shortcut() {
    local desktop_dir="${HOME}/.local/share/applications"
    local desktop_file="${desktop_dir}/mixxx-dev.desktop"
    local icon="${REPO_DIR}/res/images/icons/scalable/apps/mixxx.svg"
    [[ -f "$icon" ]] || icon="${REPO_DIR}/res/images/icons/256x256/apps/mixxx.png"

    info "Writing ${desktop_file}"
    if [[ "$DRY_RUN" == 1 ]]; then
        printf '%s+%s would write desktop entry Exec=%s run\n' \
            "$C_DIM" "$C_RESET" "${REPO_DIR}/dev.sh"
        return 0
    fi
    mkdir -p "$desktop_dir"
    cat >"$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=Mixxx (dev)
Comment=Development build from ${REPO_DIR}
Exec=${REPO_DIR}/dev.sh run
Icon=${icon}
Terminal=true
Categories=AudioVideo;Audio;
StartupNotify=true
EOF
    chmod +x "$desktop_file"
    if have update-desktop-database; then
        update-desktop-database "$desktop_dir" 2>/dev/null || true
    fi
    ok "shortcut 'Mixxx (dev)' added to your application menu"
}

cmd_doctor() {
    local buildenv
    buildenv="$(detect_buildenv 2>/dev/null || echo '(unsupported distro)')"

    printf '%sMixxx dev environment%s\n' "$C_BOLD" "$C_RESET"
    printf '  repo         %s\n' "$REPO_DIR"
    printf '  build dir    %s%s\n' "$BUILD_DIR" \
        "$(is_configured && echo ' (configured)' || echo ' (not configured)')"
    printf '  build type   %s\n' "$BUILD_TYPE"
    printf '  settings     %s\n' "$SETTINGS_DIR"
    printf '  jobs         %s\n' "$JOBS"
    printf '  buildenv     %s\n' "$buildenv"
    printf '\n%sToolchain%s\n' "$C_BOLD" "$C_RESET"

    local missing=0
    local tool
    for tool in cmake ninja ccache g++ pkg-config; do
        if have "$tool"; then
            printf '  %s%-12s%s %s\n' "$C_GREEN" "$tool" "$C_RESET" "$(command -v "$tool")"
        else
            printf '  %s%-12s%s missing\n' "$C_RED" "$tool" "$C_RESET"
            missing=1
        fi
    done

    if have mold; then
        printf '  %s%-12s%s %s\n' "$C_GREEN" "linker" "$C_RESET" "mold"
    elif have ld.lld; then
        printf '  %s%-12s%s %s\n' "$C_GREEN" "linker" "$C_RESET" "lld"
    else
        printf '  %s%-12s%s system default (slower links)\n' "$C_YELLOW" "linker" "$C_RESET"
    fi

    if have pkg-config && pkg-config --exists Qt6Core 2>/dev/null; then
        printf '  %s%-12s%s %s\n' "$C_GREEN" "Qt6" "$C_RESET" \
            "$(pkg-config --modversion Qt6Core)"
    else
        printf '  %s%-12s%s not detected via pkg-config\n' "$C_YELLOW" "Qt6" "$C_RESET"
    fi

    printf '\n'
    if (( missing )); then
        warn "some tools are missing - run './dev.sh setup'"
    else
        ok "ready to build - run './dev.sh run'"
    fi
}

usage() {
    cat <<EOF
${C_BOLD}dev.sh${C_RESET} - Mixxx development helper (Linux)

${C_BOLD}Usage${C_RESET}
  ./dev.sh [global options] <command> [command arguments]

${C_BOLD}Commands${C_RESET}
  setup        Install build dependencies for this distro (uses sudo)
  configure    Run the CMake configure step
  build        Configure if needed, then compile
  run          Build, then launch Mixxx with --developer  ${C_DIM}(default)${C_RESET}
  test         Build, then run the test suite with ctest
  clean        Delete the build directory
  shortcut     Add a "Mixxx (dev)" entry to the application menu
  doctor       Report toolchain and build directory status
  help         Show this help

${C_BOLD}Global options${C_RESET}
  -n, --dry-run        Print the commands instead of running them
  -b, --build-dir DIR  Build directory (default: ./build)
  -t, --type TYPE      CMake build type (default: RelWithDebInfo)
  -j, --jobs N         Parallel compile jobs (default: nproc)
  -h, --help           Show this help

${C_BOLD}Environment variables${C_RESET}
  BUILD_DIR, BUILD_TYPE, JOBS, SETTINGS_DIR, CMAKE_EXTRA_ARGS, DRY_RUN, NO_COLOR

${C_BOLD}Examples${C_RESET}
  ./dev.sh setup                        # once
  ./dev.sh run                          # build and launch
  ./dev.sh run --controller-debug       # extra args go to Mixxx
  ./dev.sh build --target mixxx-test    # extra args go to 'cmake --build'
  ./dev.sh -t Debug -b build-debug run  # a second, separate build
  CMAKE_EXTRA_ARGS=-DHID=OFF ./dev.sh configure
EOF
}

# ------------------------------------------------------------------ main ---

main() {
    while (( $# )); do
        case "$1" in
            -n|--dry-run)   DRY_RUN=1; shift ;;
            -b|--build-dir) [[ $# -ge 2 ]] || die "--build-dir needs a value"; BUILD_DIR="$2"; shift 2 ;;
            -t|--type)      [[ $# -ge 2 ]] || die "--type needs a value"; BUILD_TYPE="$2"; shift 2 ;;
            -j|--jobs)      [[ $# -ge 2 ]] || die "--jobs needs a value"; JOBS="$2"; shift 2 ;;
            -h|--help|help) usage; return 0 ;;
            --)             shift; break ;;
            -*)             die "unknown option: $1 (try './dev.sh help')" ;;
            *)              break ;;
        esac
    done

    local command="${1:-run}"
    if (( $# )); then
        shift
    fi

    case "$command" in
        setup)     cmd_setup "$@" ;;
        configure) cmd_configure "$@" ;;
        build)     cmd_build "$@" ;;
        run)       cmd_run "$@" ;;
        test)      cmd_test "$@" ;;
        clean)     cmd_clean "$@" ;;
        shortcut)  cmd_shortcut "$@" ;;
        doctor)    cmd_doctor "$@" ;;
        *)         die "unknown command: ${command} (try './dev.sh help')" ;;
    esac
}

main "$@"
