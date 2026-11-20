//! Usage:
//!   smc-helper serve --client-requirement '<code signing requirement>'
//!   smc-helper read <key>
//!   smc-helper auto <fanID>
//! Manual `set` is refused on the command line: manual control needs a live
//! socket session so the helper can restore automatic control if the app dies.

#[cfg(target_os = "macos")]
mod fans;
#[cfg(target_os = "macos")]
mod service;

fn usage() -> ! {
    eprintln!("usage: smc-helper serve --client-requirement <req> | read <key> | auto <fanID>");
    std::process::exit(64)
}

#[cfg(target_os = "macos")]
fn main() {
    use core_monitor_core::{helper_protocol as p, smc};
    let args: Vec<String> = std::env::args().skip(1).collect();
    let result = match args.iter().map(String::as_str).collect::<Vec<_>>().as_slice() {
        ["serve", "--client-requirement", req] => service::serve(p::SOCKET_PATH, req),
        ["read", key] => smc::validate_key(key).and_then(|k| {
            let s = fans::Fans::open()?;
            s.read(k).map(|v| println!("{v}"))
        }),
        ["auto", fan] => fan
            .parse::<i64>()
            .map_err(|_| "Fan ID must be an integer".to_string())
            .and_then(p::validate_fan_id)
            .and_then(|f| fans::Fans::open()?.set_auto(f)),
        ["set", ..] => Err("Manual fan control requires a live helper session".into()),
        _ => usage(),
    };
    if let Err(e) = result {
        eprintln!("smc-helper: {e}");
        std::process::exit(1);
    }
}

#[cfg(not(target_os = "macos"))]
fn main() {
    if std::env::args().len() < 2 {
        usage();
    }
    eprintln!("smc-helper: AppleSMC is only available on macOS");
    std::process::exit(1);
}
