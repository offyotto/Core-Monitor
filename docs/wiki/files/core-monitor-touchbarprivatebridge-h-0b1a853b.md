# File: Core-Monitor/TouchBarPrivateBridge.h

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/TouchBarPrivateBridge.h`](../../../Core-Monitor/TouchBarPrivateBridge.h) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 448 bytes |
| Binary | False |
| Line count | 15 |
| Extension | `.h` |

## Imports

None detected.

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `679aae6` | 2026-04-12 | changes. |
| `011232b` | 2026-04-11 | Update website install video |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

NSString * _Nullable CMCurrentTouchBarPresentationMode(void);
void CMSetTouchBarPresentationMode(NSString *mode);
void CMPresentTouchBarOnTop(NSTouchBar *touchBar, NSInteger placement);
void CMDismissTouchBarFromTop(NSTouchBar *touchBar);
void CMIncreaseBrightness(void);
void CMDecreaseBrightness(void);
float CMCurrentBrightness(void);
void CMSetBrightness(float value);

NS_ASSUME_NONNULL_END
```
