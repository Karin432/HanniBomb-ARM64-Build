
#!/usr/bin/env sh
# HanniBomb v1stabil - Android ARM64 build
set -eu

TARGET="aarch64-linux-android"
API="${ANDROID_API_LEVEL:-29}"
HOST_TAG="${ANDROID_NDK_HOST_TAG:-linux-x86_64}"
: "${ANDROID_NDK_HOME:?ERROR: ANDROID_NDK_HOME belum ditetapkan}"

TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG/bin"
LINKER="$TOOLCHAIN/${TARGET}${API}-clang"
OUT="${1:-bin/hannibombd}"

command -v rustc >/dev/null 2>&1 || {
    echo "ERROR: rustc tidak ditemukan" >&2
    exit 1
}

[ -x "$LINKER" ] || {
    echo "ERROR: Android NDK linker tidak ditemukan: $LINKER" >&2
    exit 1
}

mkdir -p "$(dirname "$OUT")"

echo "===== HANNIBOMB ARM64 BUILD ====="
echo "Target : $TARGET"
echo "API    : $API"
echo "Linker : $LINKER"
rustc --version

# Penting: berikan linker langsung kepada rustc.
# RUSTFLAGS tidak otomatis dibaca ketika menjalankan rustc langsung.
rustc \
    --edition=2021 \
    --target "$TARGET" \
    -C "linker=$LINKER" \
    -C link-arg=-Wl,-z,max-page-size=16384 \
    -C opt-level=z \
    -C strip=symbols \
    daemon/hannibombd.rs \
    -o "$OUT"

chmod 0755 "$OUT"

echo "===== VALIDASI BINER ====="
file "$OUT"
readelf -h "$OUT"
readelf -h "$OUT" | grep -q 'AArch64'

echo "BUILD ARM64 BERHASIL"
