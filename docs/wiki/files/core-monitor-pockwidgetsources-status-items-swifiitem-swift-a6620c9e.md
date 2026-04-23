# File: Core-Monitor/PockWidgetSources/Status/Items/SWifiItem.swift

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/PockWidgetSources/Status/Items/SWifiItem.swift`](../../../Core-Monitor/PockWidgetSources/Status/Items/SWifiItem.swift) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 2735 bytes |
| Binary | False |
| Line count | 93 |
| Extension | `.swift` |

## Imports

`AppKit`, `CoreWLAN`, `Foundation`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| class | `SWifiItem` | 9 |
| func | `didLoad` | 23 |
| func | `didUnload` | 34 |
| func | `apply` | 39 |
| func | `reload` | 43 |
| func | `imageName` | 60 |
| extension | `SWifiItem` | 75 |
| func | `linkDidChangeForWiFiInterface` | 77 |
| func | `ssidDidChangeForWiFiInterface` | 80 |
| func | `powerStateDidChangeForWiFiInterface` | 84 |
| func | `linkQualityDidChangeForWiFiInterface` | 88 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `2664fd1` | 2026-04-11 | Update Core Monitor |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
//
//  SWifiItem.swift
//  Status widget item for Core Monitor.
//

import AppKit
import CoreWLAN
import Foundation

final class SWifiItem: StatusItem {
    private let wifiClient = CWWiFiClient.shared()
    private let iconView = NSImageView(frame: NSRect(x: 0, y: 0, width: 22, height: 22))

    init() {
        didLoad()
    }

    deinit {
        didUnload()
    }

    var view: NSView { iconView }

    func didLoad() {
        wifiClient.delegate = self
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.frame.size = NSSize(width: 20, height: 20)
        reload()
        try? wifiClient.startMonitoringEvent(with: .linkDidChange)
        try? wifiClient.startMonitoringEvent(with: .ssidDidChange)
        try? wifiClient.startMonitoringEvent(with: .powerDidChange)
        try? wifiClient.startMonitoringEvent(with: .linkQualityDidChange)
    }

    func didUnload() {
        wifiClient.delegate = nil
        try? wifiClient.stopMonitoringAllEvents()
    }

    func apply(theme: TouchBarTheme) {
```
