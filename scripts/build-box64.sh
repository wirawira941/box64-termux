#!/data/data/com.termux/files/usr/bin/bash
# Build a Termux-native box64 able to run glibc x86-64 binaries (Dragon 3).
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BASE_COMMIT="${BASE_COMMIT:-420eda6}"
SRC="${SRC:-$HOME/box64}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PATCH="$HERE/../patches/box64-termux-android-glibc.patch"

for tool in git cmake clang make; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "missing '$tool' -- run: pkg install git cmake clang make" >&2
        exit 1
    }
done

if [ ! -d "$SRC/.git" ]; then
    git clone https://github.com/ptitSeb/box64.git "$SRC"
fi

git -C "$SRC" fetch origin
git -C "$SRC" checkout -f "$BASE_COMMIT"
git -C "$SRC" apply "$PATCH"

mkdir -p "$SRC/build"
cd "$SRC/build"

LD_LIBRARY_PATH="$PREFIX/lib" cmake .. \
    -DTERMUX=1 \
    -DARM64=1 \
    -DARM_DYNAREC=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo

LD_LIBRARY_PATH="$PREFIX/lib" make -j"$(nproc)"

install -m755 box64 "$PREFIX/bin/box64"
echo "installed: $("$PREFIX/bin/box64" --version | head -1)"
