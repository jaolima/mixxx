# Mixxx

[![GitHub latest tag](https://img.shields.io/github/tag/mixxxdj/mixxx.svg)](https://mixxx.org/download)
[![Packaging status](https://repology.org/badge/tiny-repos/mixxx.svg)](https://repology.org/metapackage/mixxx/versions)
[![Build status](https://github.com/mixxxdj/mixxx/actions/workflows/build.yml/badge.svg)](https://github.com/mixxxdj/mixxx/actions/workflows/build.yml)
[![Coverage status](https://coveralls.io/repos/github/mixxxdj/mixxx/badge.svg)](https://coveralls.io/github/mixxxdj/mixxx)
[![Zulip chat](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://mixxx.zulipchat.com)
[![Donate](https://img.shields.io/opencollective/all/mixxx?label=Donate)](https://mixxx.org/donate)

[Mixxx] is Free DJ software that gives you everything you need to perform live
DJ mixes. Mixxx works on GNU/Linux, Windows, and macOS.

## Development Quick Start

Two helper scripts in the repository root configure, build and launch a development build of Mixxx with a single command.

On Linux:

```shell
./dev.sh setup   # once: install the build dependencies (asks for sudo)
./dev.sh run     # configure, compile and launch in developer mode
```

On Windows, from a plain `cmd.exe` prompt:

```shell
dev.bat setup    # once: prepare the build environment (downloads ~2.5 GB)
dev.bat run      # configure, compile and launch in developer mode
```

Both scripts accept the same commands:

| Command | Description |
| ------- | ----------- |
| `setup` | Install the build dependencies for this platform |
| `configure` | Run the CMake configure step |
| `build` | Configure if needed, then compile |
| `run` | Build, then launch Mixxx with `--developer` |
| `test` | Build, then run the test suite with `ctest` |
| `clean` | Delete the build directory |
| `shortcut` | Add a "Mixxx (dev)" entry to the application menu |
| `doctor` | Report toolchain and build directory status |
| `help` | List every command and environment variable |

The scripts enable Ninja, ccache and a fast linker whenever those are installed, and they mirror the feature flags used by CI so a local build matches what the build workflow validates.
The development build keeps its settings separate from a system-wide Mixxx install, so it will not touch an existing library.

Arguments after the command are passed through.
`./dev.sh run --controller-debug` forwards the flag to Mixxx, and `./dev.sh build --target mixxx-test` forwards it to `cmake --build`.
Run `./dev.sh help` for the full list of options and environment variables such as `BUILD_DIR`, `BUILD_TYPE` and `JOBS`.

For the manual build steps these scripts wrap, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Quick Start

To get started with Mixxx:

1. For live use, [download the latest stable version][download-stable].
2. For experimentation and testing, [download a development release][download-testing].
3. To live on the bleeding edge, clone the repo: `git clone https://github.com/mixxxdj/mixxx.git`

## Bug tracker

The Mixxx team uses [Github Issues][issues] to manage Mixxx development.

Have a bug or feature request? [File a bug on Github][fileabug].

Want to get involved in Mixxx development? Assign yourself a bug from the [easy
bug list][easybugs] and get started!

## Building Mixxx

Read [CONTRIBUTING.md](CONTRIBUTING.md) for build instructions, code style
guidelines, and how to open a pull request.

## Documentation

For help using Mixxx, there are a variety of options:

- [Mixxx manual][manual]
- [Mixxx wiki][wiki]
- [Hardware Compatibility]
- [Creating Skins]

## Translation

Help to spread Mixxx with translations into more languages, as well as to update and ensure the accuracy of existing translations.

- [Help translate content]
- [Mixxx i18n wiki]
- [Mixxx localization forum]
- [Mixxx glossary]

## Community

Mixxx is a vibrant community of hackers, DJs and artists. To keep track of
development and community news:

- Chat with us on [Zulip][zulip].
- Follow us on [Mastodon], [Bluesky] and [Facebook].
- Subscribe to the [Mixxx Blog][blog].
- Post on the [Mixxx forums][discourse].

## License

Mixxx is released under the GPLv2. See the LICENSE file for a full copy of the
license.

[mixxx]: https://mixxx.org
[download-stable]: https://mixxx.org/download/#stable
[download-testing]: https://mixxx.org/download/#testing
[issues]: https://github.com/mixxxdj/mixxx/issues
[fileabug]: https://github.com/mixxxdj/mixxx/issues/new/choose
[mastodon]: https://floss.social/@mixxx
[Bluesky]: https://bsky.app/profile/mixxx.bsky.social
[facebook]: https://www.facebook.com/pages/Mixxx-DJ-Software/21723485212
[blog]: https://mixxx.org/news/
[manual]: https://manual.mixxx.org/
[wiki]: https://github.com/mixxxdj/mixxx/wiki
[easybugs]: https://github.com/mixxxdj/mixxx/issues?q=is%3Aopen+is%3Aissue+label%3Aeasy
[creating skins]: https://mixxx.org/wiki/doku.php/Creating-Skins
[help translate content]: https://explore.transifex.com/mixxx-dj-software/
[Mixxx i18n wiki]: https://github.com/mixxxdj/mixxx/wiki/Internationalization
[Mixxx localization forum]: https://mixxx.discourse.group/c/translation/13
[hardware compatibility]: https://manual.mixxx.org/2.3/en/hardware/manuals.html
[zulip]: https://mixxx.zulipchat.com/
[discourse]: https://mixxx.discourse.group/
