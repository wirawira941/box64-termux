# box64-termux

Prebuilt native build of [box64](https://github.com/ptitSeb/box64) **v0.4.5**
(base commit `420eda6`) for **Termux on Android arm64**, patched so glibc
x86-64 Linux binaries can start and run against bionic — no proot, no chroot,
no glibc-runner. The motivating workload is the commercial chess engine
**Komodo Dragon 3** (`dragon-3-linux`), but the binary is a general box64.

The patch set, build script and launcher originate from the author's own
working setup, documented in
[oncloudy/dragon3-termux](https://git.oncloudy.my.id/oncloudy/dragon3-termux)
(Forgejo). This repo adds a CI-built, checksum-verified prebuilt release so
the phone does not have to compile box64 itself.

> **Dragon 3 is commercial software.** This repository contains no Dragon
> binary or data. You must own a copy of the Linux `dragon-3-linux` binary.

## Install (prebuilt)

In Termux:

```sh
pkg install curl
curl -fLO https://raw.githubusercontent.com/wirawira941/box64-termux/main/termux/install-box64-termux.sh
sh install-box64-termux.sh
```

The installer verifies the release sha256, backs up any existing
`$PREFIX/bin/box64` to `box64.pkg-backup`, installs the `dragon` launcher to
`~/bin/dragon` (symlinked as `$PREFIX/bin/dragon`), and makes sure the
runtime dependencies are present:

- `libandroid-sysv-semaphore` — the box64 binary links it (System V
  semaphores are not in bionic; Termux ships this shim).
- `util-linux` — provides `lscpu`, which the engine calls at startup.

## Run Dragon 3

Put your engine at `~/downloads/dragon-3-linux` (or set `DRAGON_BIN`), then:

```sh
dragon
```

Point your chess GUI at `~/bin/dragon` (or `$PREFIX/bin/dragon`). The
launcher sets `BOX64_DYNACACHE=0` (the cache costs ~6 s extra at startup for
this workload) and `BOX64_NOBANNER=1`, and puts `$PREFIX/bin` on `PATH` for
the engine's `system("lscpu")` call.

## What the patch does

Against upstream box64 `420eda6`, `patches/box64-termux-android-glibc.patch`:

1. `src/emu/entrypoint.c` — also build `my___libc_start_main` on Android
   (bionic has no `__libc_start_main` for box64 to wrap, so a glibc binary's
   entry point never reached `main`).
2. `src/wrapped/wrappedlibc_private.h` — under `#ifdef ANDROID`: `GO2`
   aliases from glibc-only locale symbols (`__newlocale` family, `__strtof_l`,
   `__wcscoll_l`, `__errno_location`, `bcmp`, …) to the plain bionic names,
   and `GOM` for the gettext family.
3. `src/wrapped/wrappedlibc.c` — `my___newlocale` normalizes the glibc
   `LC_ALL` mask bit (`0x40`, rejected by bionic) and minimal gettext stubs
   return the untranslated msgid (bionic has no libintl).
4. `CMakeLists.txt` — Termux/Android builds use `-O2` instead of `-O1`.

Details: `docs/notes.md` (implementation notes) and `docs/TERMUX-NOTES.md`
(how the CI build reproduces the on-device build, and what differs).

## Build on-device instead

`scripts/build-box64.sh` is the original on-device route: it clones box64,
checks out the pinned commit, applies the patch, builds with Termux clang
(`-DTERMUX=1 -DARM64=1 -DARM_DYNAREC=ON`, RelWithDebInfo) and installs to
`$PREFIX/bin/box64`. Needs `pkg install git cmake clang make` and the
`libandroid-sysv-semaphore` package present at link time.

## Behaviour notes

- The engine reads stdin in a thread. If stdin hits EOF during
  initialization (e.g. `printf 'uci\n' | dragon`), it exits without
  answering. Real GUIs keep the pipe open, which works fine.
- `komodo.bin` (opening book) is not required; the engine runs without it.
- Measured on the author's 8-core Cortex-A55/A75 device (on-device build):
  startup to `uciok` ~10 s, ~60–68 knps at 1 thread, ~210–240 knps at
  4 threads. The CI binary is the same source, patch and flags; treat these
  numbers as the reference table for the device verdict.

## License

box64 is MIT-licensed (ptitSeb); the patches and scripts here are released
under the same terms. `libandroid-sysv-semaphore` is BSD 2-Clause
(The Android Open Source Project / Termux). Dragon 3 itself remains
proprietary and is not distributed here.
