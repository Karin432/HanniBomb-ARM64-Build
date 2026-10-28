# HanniBomb v1.5.0

- Preserved the existing purple-black WebUI and v1.4.4 low-compositing performance pass.
- Added a dependency-free Rust telemetry daemon source for Android ARM64, plus a build guide.
- Added daemon health status reporting and safe shutdown handling.
- Kept the current shell watcher as the functional profile/game fallback until a real target binary is built.
- The Rust sidecar is read-only: it reports model, Android version, memory availability, battery level/temperature, and uptime. It does not claim to tune CPU/GPU.
- Existing DNS, installed-app game picker, notifications test, color controls, network adapters and rollback routines remain in place.

## Validation caveat
This release can be syntax-checked and archive-checked here, but cannot be built into a Rust Android ARM64 binary in this environment because `rustc`, Cargo, and the Android NDK are not installed. The daemon source is therefore not shipped as a prebuilt executable and will not be falsely reported as running. Direct ColorOS 15 device testing is still required.
