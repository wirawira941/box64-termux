# Implementation notes

## Base

- box64 `420eda6` (v0.4.5), upstream `https://github.com/ptitSeb/box64`
- Built with `-DTERMUX=1 -DARM64=1 -DARM_DYNAREC=ON`
- Compiler: Termux clang, `RelWithDebInfo`

## Patch breakdown

### 1. `src/emu/entrypoint.c` — `__libc_start_main`

On Android, bionic provides neither `__libc_init` nor `__libc_start_main` in a
form box64 can wrap for glibc guests. The build previously compiled only
`my___libc_init` on Android; the patch compiles `my___libc_start_main` too, so a
glibc x86-64 program's entry point reaches the guest's `main`.

### 2. `src/wrapped/wrappedlibc_private.h` — symbol aliases

bionic has the non-`__`-prefixed versions of most locale functions. `GO2`
aliases map glibc's internal names onto them:

```
__newlocale      -> newlocale        __freelocale   -> freelocale
__duplocale      -> duplocale        __uselocale    -> uselocale
__nl_langinfo_l  -> nl_langinfo_l    __strcoll_l    -> strcoll_l
__strftime_l     -> strftime_l       __strtof_l     -> strtof_l
__strxfrm_l      -> strxfrm_l        __iswctype_l   -> iswctype_l
__strtod_l       -> strtod_l         __towlower_l   -> towlower_l
__towupper_l     -> towupper_l       __wcscoll_l    -> wcscoll_l
__wcsftime_l     -> wcsftime_l       __wcsxfrm_l    -> wcsxfrm_l
__wctype_l       -> wctype_l         bcmp           -> memcmp
__errno_location -> __errno
```

The gettext family (`gettext`, `dgettext`, `bindtextdomain`,
`bind_textdomain_codeset`) is declared with `GOM` because bionic lacks it
entirely; the generated wrapper files are updated accordingly.

### 3. `src/wrapped/wrappedlibc.c` — locale mask and gettext stubs

glibc's `newlocale` accepts `1 << LC_ALL` (0x40); bionic rejects it. libstdc++
hits this while constructing `std::locale`, which aborted the engine before
`main` on the first attempt. `my___newlocale` rewrites 0x40 to bionic's
`LC_ALL_MASK` (0x3f).

The gettext stubs return the message id (or the directory/codeset argument), so
the engine never sees a missing symbol and simply runs untranslated.

### 4. `CMakeLists.txt` — optimization

Termux builds forced `-O1`; the patch raises it to `-O2` (roughly +10% search
speed in local measurements).

## Runtime behavior

- The engine spawns `system("lscpu")` during initialization, so `lscpu` must be
  in `PATH`. The launcher exports a PATH containing `$PREFIX/bin` and
  `/system/bin`.
- Input is read by a dedicated thread with `read(0, …)`. EOF during startup
  (pipes closed early) makes the process exit quietly with only the banner
  printed; interactive/GUI usage keeps the pipe open and is unaffected.
- `BOX64_DYNACACHE=0` is used in the launcher. With the cache enabled, startup
  was ~17 s instead of ~10–11 s on the test device; the cache did not help this
  workload.

## Measurements (8-core Cortex-A55/A75, 7.6 GB RAM)

| configuration | uciok | search |
|---|---|---|
| proot + Debian box64 0.3.4 | 4.6 s | ~72 knps (1T) |
| native box64, DynaCache on | 17.6 s | ~68 knps (1T) |
| native box64, DynaCache off | 10–11 s | ~60–68 knps (1T) |
| native box64, DynaCache off, Threads=4 | 10.5 s | ~210–240 knps |

Tuning `BIGBLOCK`, `SAFEFLAGS`, `STRONGMEM`, `DIRTY`, `NOHOTPAGE`, `AVX` made no
meaningful difference to startup; the remaining cost is the embedded NN
decompression under emulation.
