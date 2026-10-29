//! HanniBomb v1.5.1 Rust telemetry daemon.
//! Read-only: never writes CPU, GPU, thermal, kernel, or touchscreen controls.

use std::{
    env, fs,
    io::Write,
    path::{Path, PathBuf},
    process::Command,
    thread,
    time::Duration,
};

const LOG_LIMIT: u64 = 256 * 1024;
const DEFAULT_INTERVAL: u64 = 15;

fn command(program: &str, args: &[&str]) -> String {
    Command::new(program)
        .args(args)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|| "unknown".to_string())
}

fn prop(key: &str) -> String {
    command("/system/bin/getprop", &[key])
        .replace(['\n', '\r'], " ")
}

fn write_status(path: &Path, content: &str) -> std::io::Result<()> {
    let tmp = path.with_extension("status.tmp");
    fs::write(&tmp, content)?;
    fs::rename(tmp, path)
}

fn append_log(path: &Path, line: &str) {
    if fs::metadata(path).map(|m| m.len() >= LOG_LIMIT).unwrap_or(false) {
        let old = path.with_extension("log.old");
        let _ = fs::remove_file(&old);
        if fs::rename(path, old).is_err() {
            let _ = fs::remove_file(path);
        }
    }

    if let Ok(mut file) = fs::OpenOptions::new().create(true).append(true).open(path) {
        let _ = writeln!(file, "{}", line.replace(['\n', '\r'], " "));
    }
}

fn battery_info() -> (String, String) {
    let output = command("/system/bin/dumpsys", &["battery"]);
    let mut level = "unknown".to_string();
    let mut temp = "unknown".to_string();

    for line in output.lines() {
        let line = line.trim();
        if line.starts_with("level:") {
            level = line["level:".len()..].trim().to_string();
        } else if line.starts_with("temperature:") {
            temp = line["temperature:".len()..].trim().to_string();
        }
    }

    (level, temp)
}


// Read-only thermal telemetry; never writes thermal or performance controls.
fn thermal_info() -> (usize, String, String) {
    let root = Path::new("/sys/class/thermal");
    let entries = match fs::read_dir(root) {
        Ok(entries) => entries,
        Err(_) => return (0, "unknown".to_string(), "unavailable".to_string()),
    };

    let mut count = 0usize;
    let mut max_celsius: Option<i64> = None;
    let mut max_zone = "unknown".to_string();

    for entry in entries.flatten() {
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().to_string();

        if !name.starts_with("thermal_zone") {
            continue;
        }

        let raw = match fs::read_to_string(path.join("temp")) {
            Ok(value) => match value.trim().parse::<i64>() {
                Ok(value) => value,
                Err(_) => continue,
            },
            Err(_) => continue,
        };

        // Android usually reports millidegrees Celsius.
        let celsius = if raw.abs() > 1000 { raw / 1000 } else { raw };

        if !(-20..=150).contains(&celsius) {
            continue;
        }

        count += 1;

        if max_celsius.map(|current| celsius > current).unwrap_or(true) {
            max_celsius = Some(celsius);
            max_zone = fs::read_to_string(path.join("type"))
                .map(|value| value.trim().replace(['\n', '\r'], " "))
                .ok()
                .filter(|value| !value.is_empty())
                .unwrap_or(name);
        }
    }

    let max = max_celsius
        .map(|value| value.to_string())
        .unwrap_or_else(|| "unknown".to_string());

    (count, max, max_zone)
}

fn should_stop(module: &Path, data: &Path) -> bool {
    !module.exists()
        || module.join("disable").exists()
        || data.join("stop_rust_daemon").exists()
}

fn cleanup(pid: &Path, status: &Path) {
    let current_pid = std::process::id().to_string();

    // Remove only files that still identify this daemon instance.
    if fs::read_to_string(pid)
        .map(|value| value.trim() == current_pid)
        .unwrap_or(false)
    {
        let _ = fs::remove_file(pid);
    }

    let expected = format!("pid={}", current_pid);
    if fs::read_to_string(status)
        .map(|content| content.lines().any(|line| line == expected))
        .unwrap_or(false)
    {
        let _ = fs::remove_file(status);
    }
}

fn main() {
    let moddir = env::var("HANNIBOMB_MODDIR")
        .unwrap_or_else(|_| "/data/adb/modules/hannibomb".to_string());
    let datadir = env::var("HANNIBOMB_DATA_DIR")
        .unwrap_or_else(|_| "/data/adb/hannibomb".to_string());

    let module = PathBuf::from(moddir);
    let data = PathBuf::from(datadir);

    let interval = env::var("HANNIBOMB_POLL_SECONDS")
        .ok()
        .and_then(|v| v.parse::<u64>().ok())
        .unwrap_or(DEFAULT_INTERVAL)
        .clamp(5, 300);

    if fs::create_dir_all(&data).is_err() {
        eprintln!("HanniBomb Rust: cannot create data directory");
        return;
    }

    let pid_path = data.join("rust_daemon.pid");
    let status_path = data.join("rust_daemon.status");
    let log_path = data.join("rust_daemon.log");

    if fs::write(&pid_path, std::process::id().to_string()).is_err() {
        eprintln!("HanniBomb Rust: cannot write PID file");
        return;
    }

    append_log(
        &log_path,
        &format!(
            "[HanniBomb Rust] started pid={} interval={}s",
            std::process::id(),
            interval
        ),
    );

    loop {
        if should_stop(&module, &data) {
            break;
        }

        let uptime = fs::read_to_string("/proc/uptime")
            .unwrap_or_else(|_| "unknown".to_string())
            .split_whitespace()
            .next()
            .unwrap_or("unknown")
            .to_string();

        let mem_available = fs::read_to_string("/proc/meminfo")
            .ok()
            .and_then(|contents| {
                contents.lines()
                    .find(|line| line.starts_with("MemAvailable:"))
                    .map(|line| line.trim().to_string())
            })
            .unwrap_or_else(|| "unknown".to_string());

        let (battery_level, battery_temp) = battery_info();
        let (thermal_zone_count, thermal_max_celsius, thermal_max_zone) = thermal_info();

        let status = format!(
            "daemon=rust\nstate=running\npid={}\nandroid={}\nmodel={}\nmem_available={}\nbattery_level={}\nbattery_temperature={}\nthermal_zone_count={}\nthermal_max_celsius={}\nthermal_max_zone={}\nuptime_seconds={}\npoll_seconds={}\n",
            std::process::id(),
            prop("ro.build.version.release"),
            prop("ro.product.model"),
            mem_available,
            battery_level,
            battery_temp,
            thermal_zone_count,
            thermal_max_celsius,
            thermal_max_zone,
            uptime,
            interval
        );

        if let Err(error) = write_status(&status_path, &status) {
            append_log(&log_path, &format!("[HanniBomb Rust] status write failed: {}", error));
        }

        thread::sleep(Duration::from_secs(interval));
    }

    append_log(&log_path, "[HanniBomb Rust] stopped");
    cleanup(&pid_path, &status_path);
}
