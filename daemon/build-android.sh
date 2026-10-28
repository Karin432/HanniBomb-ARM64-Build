#!/system/bin/sh
# Run on a build host with Rust and Android NDK installed (not on the phone).
set -eu
command -v rustc >/dev/null 2>&1 || { echo 'ERROR: rustc is required' >&2; exit 1; }
: "${ANDROID_NDK_HOME:?Set ANDROID_NDK_HOME to Android NDK path}"
HOST_TAG=${ANDROID_NDK_HOST_TAG:-linux-x86_64}
API=${ANDROID_API_LEVEL:-29}
TARGET=aarch64-linux-android
TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_TAG/bin"
[ -x "$TOOLCHAIN/${TARGET}${API}-clang" ] || { echo "ERROR: NDK linker not found: $TOOLCHAIN/${TARGET}${API}-clang" >&2; exit 1; }
OUT=${1:-bin/hannibombd}
mkdir -p "$(dirname "$OUT")"
RUSTFLAGS="-C linker=$TOOLCHAIN/${TARGET}${API}-clang -C link-arg=-Wl,-z,max-page-size=16384" \
  rustc --edition=2021 --target "$TARGET" -C opt-level=z -C strip=symbols daemon/hannibombd.rs -o "$OUT"
chmod 0755 "$OUT"
file "$OUT" 2>/dev/null || true
