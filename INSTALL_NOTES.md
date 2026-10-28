# HanniBomb v1.5.0 — install and validation notes

1. Install `HanniBomb_v1.5.0_KSU_Install.zip` from KernelSU Manager as a module/update and reboot.
2. Open HanniBomb WebUI and check the system status and output log.
3. Use **Uji notifikasi Android** to test notification posting; a successful command return does not guarantee that Android displays it if system notification permissions/policy block it.
4. Test the installed-app picker and save a game; auto game profile remains opt-in and is only checked by the fallback watcher at its configured interval.
5. DNS/traffic controls are separate and should only be enabled intentionally. Color saturation support depends on the ColorOS build; increasing saturation cannot physically change an LCD panel into AMOLED.

## Rust daemon status
This ZIP includes Rust source and a build script, not a prebuilt Android executable. The build environment used for this package does not have Rust/Cargo/Android NDK, so the module honestly falls back to the existing shell watcher until `bin/hannibombd` is built for `aarch64-linux-android` and placed in the module. Do not treat the Rust sidecar as active until WebUI status reports `RUST_DAEMON_STATE=running` and the status file shows `daemon=rust`.

The existing shell runtime remains the active profile/game controller in this version; the Rust source is a read-only telemetry sidecar and does not yet replace profile logic.
