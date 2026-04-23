# File: Core-Monitor/EasterEggLab.swift

## Current Role

- Area: Kernel Panic / Weird Mode.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/EasterEggLab.swift`](../../../Core-Monitor/EasterEggLab.swift) |
| Wiki area | Kernel Panic / Weird Mode |
| Exists in current checkout | True |
| Size | 2454 bytes |
| Binary | False |
| Line count | 55 |
| Extension | `.swift` |

## Imports

`SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `KernelPanicPreferences` | 2 |
| struct | `EasterEggLabCard` | 7 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `aca5d59` | 2026-04-19 | Add Kernel Panic release payload |
| `210356e` | 2026-04-19 | Add Kernel Panic release payload |
| `29afd92` | 2026-04-18 | Ship 14.0.7 localization update |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import SwiftUI

enum KernelPanicPreferences {
    static let enabledKey = "coremonitor.easterEggsEnabled"
    static let bestScoreKey = "coremonitor.kernelPanicBestScore"
}

struct EasterEggLabCard: View {
    @AppStorage(KernelPanicPreferences.enabledKey) private var easterEggsEnabled = false
    @AppStorage(KernelPanicPreferences.bestScoreKey) private var bestScore = 0

    var body: some View {
        DarkCard(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weird Easter Eggs")
                            .font(.system(size: 18, weight: .bold))
                        Text("Opt into the deliberately odd extras that do not belong in a thermal monitor, now starring a monochrome battle-box Kernel Panic.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(easterEggsEnabled ? "Enabled" : "Disabled")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(easterEggsEnabled ? .green : .secondary)
                        Text(bestScore == 0 ? "No panic contained yet" : "Best purge \(KernelPanicArcade.scoreString(bestScore))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $easterEggsEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Enable weird mode")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Unlocks Kernel Panic, a fictional parody boss rush with an original monochrome battle-box look and zero real malware behavior.")
```
