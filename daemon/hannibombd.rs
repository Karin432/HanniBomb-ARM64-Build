//! HanniBomb telemetry sidecar for Android ARM64.
//! Read-only by design: it reports health and device telemetry; profile writes stay in the
//! existing validated shell adapters until a device-specific Rust adapter is tested.
use std::{env, fs, path::Path, process::Command, thread, time::Duration};

fn command(program: &str, args: &[&str]) -> String {
    Command::new(program).args(args).output().ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string()).unwrap_or_default()
}
fn prop(key: &str) -> String { command("/system/bin/getprop", &[key]) }
fn write_status(path: &Path, text: &str) {
    let tmp = path.with_extension("tmp");
    if fs::write(&tmp, text).is_ok() { let _ = fs::rename(tmp, path); }
}
fn main() {
    let moddir = env::var("HANNIBOMB_MODDIR").unwrap_or_else(|_| "/data/adb/modules/hannibomb".into());
    let data = env::var("HANNIBOMB_DATA_DIR").unwrap_or_else(|_| "/data/adb/hannibomb".into());
    let module = Path::new(&moddir); let data_path = Path::new(&data);
    let _ = fs::create_dir_all(data_path);
    let pid_path = data_path.join("rust_daemon.pid");
    let status_path = data_path.join("rust_daemon.status");
    let _ = fs::write(&pid_path, std::process::id().to_string());
    let log_path = data_path.join("rust_daemon.log");
    let mut last_log = String::new();
    loop {
        if !module.exists() || module.join("disable").exists() || data_path.join("stop_rust_daemon").exists() { break; }
        let uptime = fs::read_to_string("/proc/uptime").unwrap_or_default();
        let mem = fs::read_to_string("/proc/meminfo").unwrap_or_default();
        let mem_available = mem.lines().find(|l| l.starts_with("MemAvailable:")).unwrap_or("MemAvailable: unknown");
        let battery = command("/system/bin/dumpsys", &["battery"]);
        let level = battery.lines().find(|l| l.trim_start().starts_with("level:")).unwrap_or("level: unknown").trim().to_string();
        let temp = battery.lines().find(|l| l.trim_start().starts_with("temperature:")).unwrap_or("temperature: unknown").trim().to_string();
        let status = format!("daemon=rust\nstate=running\npid={}\nandroid={}\nmodel={}\nmem_available={}\nbattery_{}\nbattery_{}\nuptime={}\n", std::process::id(), prop("ro.build.version.release"), prop("ro.product.model"), mem_available.trim(), level, temp, uptime.trim());
        write_status(&status_path, &status);
        if last_log.is_empty() {
            let line = format!("[HanniBomb Rust] started pid={} android={} model={} {} {}", std::process::id(), prop("ro.build.version.release"), prop("ro.product.model"), level, temp);
            let _ = fs::OpenOptions::new().create(true).append(true).open(&log_path).and_then(|mut f| std::io::Write::write_all(&mut f, format!("{}\n", line).as_bytes()));
            last_log = "started".to_string();
        }
        thread::sleep(Duration::from_secs(15));
    }
    let _ = fs::remove_file(&pid_path); let _ = fs::remove_file(&status_path);
    let _ = fs::remove_file(data_path.join("stop_rust_daemon"));
}
