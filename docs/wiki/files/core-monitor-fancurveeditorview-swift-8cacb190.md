# File: Core-Monitor/FanCurveEditorView.swift

## Current Role

- Area: Fan control, SMC, or helper.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/FanCurveEditorView.swift`](../../../Core-Monitor/FanCurveEditorView.swift) |
| Wiki area | Fan control, SMC, or helper |
| Exists in current checkout | True |
| Size | 34798 bytes |
| Binary | False |
| Line count | 901 |
| Extension | `.swift` |

## Imports

`AppKit`, `SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| struct | `FanCurveCard` | 3 |
| enum | `FanCurveChartGeometry` | 20 |
| struct | `FanCurvePreview` | 111 |
| func | `grid` | 189 |
| func | `fillPath` | 205 |
| func | `linePath` | 214 |
| func | `chartPoint` | 227 |
| func | `pointHandle` | 231 |
| func | `chartGesture` | 249 |
| enum | `FanCurveTemplate` | 274 |
| struct | `CustomFanPresetEditorSheet` | 290 |
| func | `templateButton` | 629 |
| func | `labeledTextField` | 637 |
| func | `integerStepper` | 648 |
| func | `numericSlider` | 670 |
| func | `pointRow` | 693 |
| func | `temperatureBinding` | 733 |
| func | `speedBinding` | 744 |
| func | `updatePoint` | 755 |
| func | `removePoint` | 783 |
| func | `addPoint` | 795 |
| func | `applyTemplate` | 814 |
| func | `save` | 861 |
| extension | `Array` | 894 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `5691635` | 2026-04-16 | Improve custom fan curve editing |
| `7185d36` | 2026-04-15 | Improve fan control and alert surfaces |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
import AppKit
import SwiftUI

private struct FanCurveCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
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

enum FanCurveChartGeometry {
    static let temperatureRange: ClosedRange<Double> = 30...110
    static let speedRange: ClosedRange<Double> = 0...100
    static let pointInset: CGFloat = 12
    static let handleSelectionRadius: CGFloat = 28

    static func plotPoint(
        for point: CustomFanPreset.CurvePoint,
        size: CGSize
    ) -> CGPoint {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let innerWidth = max(width - (pointInset * 2), 1)
        let innerHeight = max(height - (pointInset * 2), 1)
        let xRatio = (point.temperatureC - temperatureRange.lowerBound) / (temperatureRange.upperBound - temperatureRange.lowerBound)
        let yRatio = point.speedPercent / speedRange.upperBound

        return CGPoint(
            x: pointInset + (CGFloat(xRatio) * innerWidth),
            y: height - (pointInset + (CGFloat(yRatio) * innerHeight))
```
