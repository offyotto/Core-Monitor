# File: Core-Monitor/MonitoringDashboardViews.swift

## Current Role

- Area: Dashboard.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/MonitoringDashboardViews.swift`](../../../Core-Monitor/MonitoringDashboardViews.swift) |
| Wiki area | Dashboard |
| Exists in current checkout | True |
| Size | 14362 bytes |
| Binary | False |
| Line count | 393 |
| Extension | `.swift` |

## Imports

`SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `DashboardSurfaceCard` | 2 |
| struct | `MonitoringDashboardStrip` | 19 |
| func | `statusCard` | 116 |
| func | `monitoringColor` | 138 |
| func | `pillColor` | 161 |
| struct | `SystemStatusBoard` | 177 |
| func | `statusCard` | 271 |
| func | `monitoringColor` | 293 |
| func | `thermalStateLabel` | 316 |
| func | `pillColor` | 331 |
| struct | `TopMemoryProcessesPanel` | 347 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `4e417f6` | 2026-04-17 | Remove Alerts screen surface |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import SwiftUI

private struct DashboardSurfaceCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .background(
                CoreMonGlassBackground(
                    cornerRadius: 18,
                    tintOpacity: 0.12,
                    strokeOpacity: 0.14,
                    shadowRadius: 10
                )
            )
    }
}

struct MonitoringDashboardStrip: View {
    @ObservedObject var systemMonitor: SystemMonitor
    @ObservedObject var fanController: FanController
    @ObservedObject private var helperManager = SMCHelperManager.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let health = systemMonitor.snapshotHealth(now: context.date)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statusCard(
                    title: "Monitoring",
                    value: health.statusLabel,
                    detail: "\(health.ageDescription). \(health.cadenceDescription).",
                    icon: "waveform.path.ecg.rectangle",
                    color: monitoringColor(health)
                )
                statusCard(
                    title: "Overall Thermal",
                    value: AlertEvaluator.thermalStateLabel(systemMonitor.thermalState),
                    detail: CoreMonitorPlatformCopy.thermalStatusDetail(),
```
