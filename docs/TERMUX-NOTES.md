# TERMUX-NOTES — how the CI build reproduces the on-device build

- Upstream: https://github.com/ptitSeb/box64 — pinned base commit
  **420eda69ff51ab5d5a7cbc3dee2e70433be3411d** (master, 2026-10-23, just after
  the v0.4.5-1 tag; the author's README calls it "v0.4.5"). The patch does
  NOT apply to the v0.4.5-1 tag (its generated-file hunks differ), so the
  commit pin is load-bearing — do not "upgrade" it to the tag.
- Origin of the port: the author's own Forgejo repo
  https://git.oncloudy.my.id/oncloudy/dragon3-termux holds the original
  patch, on-device build script and launcher, proven on-device with
  Komodo Dragon 3. This repo keeps those files and adds a prebuilt release.
- CI recipe (`.github/workflows/build-termux.yml`) mirrors the local proof
  build done on the maintainer VM with NDK r28c:
  1. fetch box64 at the pinned commit, `git apply` the patch;
  2. build `libandroid-sysv-semaphore` from the exact Termux package source
     (termux-packages `packages/libandroid-sysv-semaphore/sys_sem.c`,
     `-D__USE_GNU -fPIC`, shared) — box64 links `-landroid-sysv-semaphore`
     only for `ANDROID AND TERMUX` (CMakeLists) and the NDK does not ship it;
  3. cmake with the NDK toolchain: `ANDROID_ABI=arm64-v8a`,
     `TERMUX=1 ARM64=1 ARM_DYNAREC=ON`, `CMAKE_BUILD_TYPE=RelWithDebInfo`,
     linker flags `-L<shim dir> -Wl,-rpath,/data/data/com.termux/files/usr/lib`;
  4. strip, then a hard ELF gate (below), then tarball + sha256 + release.
- ANDROID_PLATFORM must be **>= 28**: bionic only exposes `glob`/`globfree`
  from API 28, and upstream `src/steam.c` uses them. The local proof build
  with API 24 died in steam.c with implicit-declaration errors. (The
  on-device Termux clang targets the device API, so it never hits this.)
  API 28 = Android 9+ baseline for the prebuilt binary.
- The only intentional difference from the on-device build is the compiler
  (NDK cross clang instead of Termux clang) and the platform level above.
  Source, patch, CMake options and build type are identical.
- ELF gate (CI fails the release unless all hold): Type DYN (PIE),
  Machine AArch64, interpreter `/system/bin/linker64`; NEEDED contains
  `libandroid-sysv-semaphore.so`; dynamic symbols contain
  `my___libc_start_main` and `my___newlocale` (patch evidence); version
  string present. The local proof binary additionally had NEEDED limited to
  libc/libm/libdl + the shim, and RUNPATH `/data/data/com.termux/files/usr/lib`.
- Runtime requirements on device: Termux packages
  `libandroid-sysv-semaphore` (linked by the binary; found via the baked-in
  RUNPATH once installed into `$PREFIX/lib`) and `util-linux` (`lscpu`).
  The installer ensures both.
- The release binary is stripped (the on-device RelWithDebInfo build keeps
  debug info; stripping changes size only, not behaviour).
- Device verdict is the closer: install the release, run Dragon through the
  `dragon` launcher, compare `uciok` startup and bench knps against the
  reference table in README.md (author's on-device measurements).
