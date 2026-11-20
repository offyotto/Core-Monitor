# Core-Monitor in Rust

A Rust rewrite of Core-Monitor. It is a Cargo workspace with four crates.

| Crate | What it does |
| --- | --- |
| `crates/core` (`core-monitor-core`) | Pure logic. It has the data models, SMC value codecs, the sensor catalog for M1 to M5 and Intel, trends and freshness, the alert rules and presets, the alert evaluator, fan modes, the custom curve presets, fan leases, the helper wire protocol, and formatting. It builds and tests on any OS. |
| `crates/sys` (`core-monitor-sys`) | macOS hardware access. It reads AppleSMC through IOKit, CPU ticks and VM stats through Mach, swap and disk through `sysctl` and `statfs`, 64-bit network counters through `NET_RT_IFLIST2`, battery data through IOPS and `AppleSmartBattery`, thermal state through `NSProcessInfo`, and top processes through libproc. On other OSes it reports that the platform is not supported. |
| `crates/smc-helper` | The privileged fan helper. It runs as a launchd daemon. |
| `crates/app` (`core-monitor`) | The menu bar item (`tray-icon`) and the dashboard window (`eframe`/`egui`). |

## Build and test

```bash
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
./scripts/bundle.sh            # build/rust/Core-Monitor.app (set CODESIGN_IDENTITY to sign it)
```

## Fan helper

The Swift helper used XPC through `SMJobBless`. The Rust helper serves newline-delimited JSON on `/var/run/core-monitor.smc-helper.sock` and keeps the same safety rules:

- Each connection must pass a code signing requirement. The helper checks it against the peer's audit token (`LOCAL_PEERTOKEN`, then `SecCodeCheckValidity`).
- Fan IDs must be 0 to 9. A requested RPM must be 500 to 10,000. It must also fall inside the fan's reported range, limited to 1,000 to 6,500 RPM. A request outside that range is rejected, not clamped.
- SMC keys must be exactly four printable ASCII characters.
- Each client owns the fans it writes through a 15-second lease. The app renews the lease every 5 seconds. The helper returns a fan to automatic control when its client disconnects or its lease expires. If that restore fails, the helper tries again every second.
- `smc-helper set` on the command line is refused, because manual control needs a live session for crash recovery. `smc-helper read <key>` and `smc-helper auto <fan>` still work.

To install the helper:

```bash
sudo ./scripts/install-helper.sh ../build/rust/Core-Monitor.app/Contents/Library/LaunchServices/ventaphobia.smc-helper-rs
```

It uses its own launchd label (`ventaphobia.smc-helper-rs`) and socket, so it does not replace the Swift app's `ventaphobia.smc-helper`. The default client requirement only admits the signed release app (`CoreTools.Core-Monitor`, team `6VDP675K4L`). For a local build, pass your own requirement as the second argument.

## Settings

Settings, alert state, and the custom fan preset are stored in `~/Library/Application Support/Core-Monitor/`. The file `custom-fan-preset.json` uses the same JSON format as the Swift app.

## Not ported yet

- **Touch Bar widgets.** There are no maintained Rust bindings for the private `NSTouchBar` system-modal API that the Swift app uses.
- **WeatherKit.** WeatherKit and CoreLocation need entitlements and Swift-only async APIs.
- **Mac App Store edition.** The sandboxed, read-only build is not ported.
- **Some Swift-only UI.** Onboarding, localization, the help views, launch at login, and the menu bar popover panels are not ported. The menu bar item shows CPU load, temperature, and alert state, and it can open the dashboard and switch the fan mode.
- **`SMJobBless` install flow.** Install the helper with `scripts/install-helper.sh` for now.
