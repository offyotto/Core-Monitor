# Runtime behavior and validation

## Fan control

Manual and managed fan targets belong to a signed app's persistent XPC connection. The helper records a 15-second lease before writing each fan. The app renews leases every two seconds, including when the target RPM has not changed. Connection loss immediately expires that client's leases. The helper checks expiry once per second on its serialized hardware queue and attempts to restore automatic control; failed restores stay queued for retry.

Update the app and reinstall the bundled helper together. The app checks the helper's safety protocol before issuing manual writes. Older helpers cannot pass that check. Standalone CLI `set` is no longer supported because a process that exits cannot supervise a manual override; CLI `read` and `auto` remain available. Supported fan IDs are 0–9, matching the existing single-decimal-character SMC key format.

The watchdog depends on a running helper and responsive hardware calls. It does not claim recovery from a helper/system crash or a permanently failing SMC. Signing, installation, sleep/wake, real fan restoration, and thermal behavior still require validation on a fan-equipped Apple Silicon Mac. Automated tests cover ownership, disconnect/expiry, renewal, failed-restore retries, and asynchronous XPC using an anonymous test listener without privileged hardware access.

## Monitoring

- Stopping or restarting a sampling session invalidates outstanding results. Turning off process insights also prevents old process results from repopulating the snapshot.
- CPU fallback values and network baselines belong to the sampling queue. Published UI snapshots are accessed on the main thread.
- Network rates use 64-bit counters per interface. Newly added or reset interfaces establish a new baseline; one interface disappearing does not zero the others' rates.
- Disk process counters include the kernel process start time. A reused PID starts a new baseline even when its counters exceed those of the previous process.
- Privacy changes reach alert redaction and persistence on the main run loop, including changes published by a background thread.

## Single-instance startup

A per-user application-support file holds a kernel lock for the primary app's lifetime. Its PID metadata is used only for routing: a stale PID never prevents acquiring a released lock. Other launches retry a dashboard request until the owner acknowledges it, or take over if the owner exits. A nonresponding owner produces an explicit startup message instead of a second monitoring instance. Requests use a string object and no notification dictionary for App Sandbox compatibility.

Quit older builds before launching this version: builds without the new lock protocol cannot participate in its election. The lock file must not be deleted while the app is running.

## Windows, language, weather, and alerts

- Closing the dashboard preserves its controller and frame for reopening. Existing off-screen recovery still applies after display changes.
- Battery descriptions and number/date formatting follow the selected app locale. All nine battery strings have entries for the 112 advertised locales. Newly added or corrected translations are marked `needs_review` in the catalog for native-speaker review; automated tests verify compiled coverage and formatting placeholders, not linguistic accuracy. Duration units use the platform formatter.
- A failed weather refresh may retain a cached reading only while it is younger than the configured refresh interval. Older readings give way to an error or an available fallback provider.
- Weather place names reuse the most recent successful lookup for up to one hour and within 500 metres, provided the app locale is unchanged. Concurrent matching lookups share one request. The cache is in memory only; failed lookups can retry. The app sends location to Apple for weather and place names, while the developer does not receive it.
- Repeated desktop notifications use one identifier per alert rule. In-app history, severity changes, and repeat cooldowns retain their existing behavior.

Physical fan tests and manual visual inspection are not replaced by the automated suite.
