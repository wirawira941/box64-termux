#!/data/data/com.termux/files/usr/bin/sh
# Install the prebuilt patched box64 (Dragon 3 capable) on Termux.
# - Downloads the release tarball and verifies its sha256 before installing.
# - Backs up an existing $PREFIX/bin/box64 once to box64.pkg-backup.
# - Installs the `dragon` launcher to ~/bin/dragon and symlinks it into
#   $PREFIX/bin so chess GUIs can point at either path.
# - Ensures the runtime deps: libandroid-sysv-semaphore (the box64 binary
#   links it) and util-linux (the engine calls `lscpu` at startup).
set -eu

TAG="v0.4.5-termux.1"
VER="0.4.5"
ASSET="box64_${VER}_termux_arm64.tar.gz"
SHA256="TO_BE_FILLED_AFTER_CI"
URL="https://github.com/wirawira941/box64-termux/releases/download/${TAG}/${ASSET}"

if [ -z "${PREFIX:-}" ]; then
    echo "install-box64-termux: \$PREFIX is empty -- run this inside Termux itself, not inside proot/chroot." >&2
    exit 1
fi

for pkg in libandroid-sysv-semaphore util-linux; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "installing Termux package: $pkg"
        pkg install -y "$pkg"
    fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "downloading $ASSET ($TAG)"
curl -fL -o "$WORK/$ASSET" "$URL"
echo "${SHA256}  ${WORK}/${ASSET}" | sha256sum -c -

tar -xzf "$WORK/$ASSET" -C "$WORK"

if [ -x "$PREFIX/bin/box64" ] && [ ! -e "$PREFIX/bin/box64.pkg-backup" ]; then
    cp -a "$PREFIX/bin/box64" "$PREFIX/bin/box64.pkg-backup"
    echo "existing box64 backed up to $PREFIX/bin/box64.pkg-backup"
fi

install -m 0755 "$WORK/box64" "$PREFIX/bin/box64"
mkdir -p "$HOME/bin"
install -m 0755 "$WORK/dragon" "$HOME/bin/dragon"
ln -sf "$HOME/bin/dragon" "$PREFIX/bin/dragon"

echo "installed:"
"$PREFIX/bin/box64" --version | head -1
echo "launcher: ~/bin/dragon (also linked as \$PREFIX/bin/dragon)"
echo "engine path defaults to ~/downloads/dragon-3-linux; override with DRAGON_BIN."
