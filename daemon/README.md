# HanniBomb Rust daemon (v1stabil)

The source is dependency-free and read-only. It publishes health telemetry to `/data/adb/hannibomb/rust_daemon.status`; it does not write CPU/GPU/kernel controls. The existing validated shell watcher remains responsible for adaptive/game profile decisions.

## Build for the target
Use a Rust toolchain plus Android NDK. Set the Android target and linker for the NDK clang wrapper, then build `hannibombd.rs` as a binary for `aarch64-linux-android`. Copy the resulting executable to `bin/hannibombd` in the module and set mode 0755. `build-android.sh` documents the expected environment and refuses to pretend a binary exists when the toolchain is missing.

No prebuilt binary is shipped in this source package because the build environment used to prepare this release has no Rust compiler or Android NDK. Until a target binary is built and installed, service.sh deliberately uses the tested shell watcher fallback.
