# File: Core-Monitor/TouchBarPrivateBridge.m

## Current Role

- Area: Touch Bar and Pock widget runtime.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/TouchBarPrivateBridge.m`](../../../Core-Monitor/TouchBarPrivateBridge.m) |
| Wiki area | Touch Bar and Pock widget runtime |
| Exists in current checkout | True |
| Size | 8260 bytes |
| Binary | False |
| Line count | 216 |
| Extension | `.m` |

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
#import "TouchBarPrivateBridge.h"
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/hidsystem/IOHIDLib.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>

static CFStringRef const CMKPresentationModeGlobal = CFSTR("PresentationModeGlobal");
static CFStringRef const CMKTouchBarAgentIdentifier = CFSTR("com.apple.touchbar.agent");
static mach_port_t sCMEventDriverRef = 0;
typedef double (*CMCoreDisplayGetBrightnessFn)(uint32_t);
typedef void (*CMCoreDisplaySetBrightnessFn)(uint32_t, double);

@interface NSTouchBar (CoreMonitorPrivate)
+ (void)presentSystemModalFunctionBar:(nullable NSTouchBar *)touchBar placement:(long long)placement systemTrayItemIdentifier:(nullable NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalFunctionBar:(nullable NSTouchBar *)touchBar;
+ (void)presentSystemModalTouchBar:(nullable NSTouchBar *)touchBar placement:(long long)placement systemTrayItemIdentifier:(nullable NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalTouchBar:(nullable NSTouchBar *)touchBar;
@end

static io_connect_t CMEventDriver(void) {
    if (sCMEventDriverRef != 0) {
        return sCMEventDriverRef;
    }

    mach_port_t masterPort = 0;
    io_iterator_t iterator = 0;
    io_service_t service = 0;
    kern_return_t kr = IOMainPort(MACH_PORT_NULL, &masterPort);
    if (kr != KERN_SUCCESS) {
        return IO_OBJECT_NULL;
    }

    kr = IOServiceGetMatchingServices(masterPort, IOServiceMatching(kIOHIDSystemClass), &iterator);
    if (kr != KERN_SUCCESS) {
        return IO_OBJECT_NULL;
    }

    service = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
```
