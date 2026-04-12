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
    if (service == IO_OBJECT_NULL) {
        return IO_OBJECT_NULL;
    }

    kr = IOServiceOpen(service, mach_task_self(), kIOHIDParamConnectType, &sCMEventDriverRef);
    IOObjectRelease(service);
    if (kr != KERN_SUCCESS) {
        sCMEventDriverRef = 0;
        return IO_OBJECT_NULL;
    }

    return sCMEventDriverRef;
}

static void CMSendAuxKey(uint16_t keyCode, BOOL keyDown) {
    // On macOS 11 and later, avoid deprecated IOHIDPostEvent by posting a system-defined event via CGEvent.
#if __MAC_OS_X_VERSION_MAX_ALLOWED >= 110000
    if (@available(macOS 11.0, *)) {
        // Encode the same data layout used previously for NX_SYSDEFINED/NX_SUBTYPE_AUX_CONTROL_BUTTONS
        // data1 packs: high 16 bits = keyCode, next 8 bits = key state, low 8 bits unused
        int32_t data1 = ((int32_t)keyCode << 16) | (((int32_t)(keyDown ? NX_KEYDOWN : NX_KEYUP)) << 8);
        NSEvent *event = [NSEvent otherEventWithType:NSEventTypeSystemDefined
                                            location:NSZeroPoint
                                       modifierFlags:0
                                           timestamp:0
                                        windowNumber:0
                                             context:nil
                                             subtype:NX_SUBTYPE_AUX_CONTROL_BUTTONS
                                               data1:data1
                                               data2:0];
        CGEventRef cgEvent = [event CGEvent];
        if (cgEvent) {
            CGEventPost(kCGHIDEventTap, cgEvent);
        }
        return;
    }
#endif
    // Fallback for older macOS versions using IOHIDPostEvent (deprecated on macOS 11+)
    io_connect_t driver = CMEventDriver();
    if (driver == IO_OBJECT_NULL) {
        return;
    }

    NXEventData eventData = {0};
    eventData.compound.subType = NX_SUBTYPE_AUX_CONTROL_BUTTONS;
    eventData.compound.misc.L[0] = (((keyDown ? NX_KEYDOWN : NX_KEYUP) << 8) | (keyCode << 16));
    // Suppress deprecation warning for legacy path
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    IOHIDPostEvent(driver, NX_SYSDEFINED, (IOGPoint){0}, &eventData, kNXEventDataVersion, 0, 0);
#pragma clang diagnostic pop
}

static void CMSendMediaKeyTap(uint16_t keyCode) {
    CMSendAuxKey(keyCode, YES);
    CMSendAuxKey(keyCode, NO);
}

static float CMReadBrightnessFallback(void) {
    float brightness = 0;
    io_iterator_t iterator = IO_OBJECT_NULL;
    kern_return_t result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator);
    if (result != KERN_SUCCESS) {
        return 0;
    }

    io_service_t service = IOIteratorNext(iterator);
    while (service != IO_OBJECT_NULL) {
        IODisplayGetFloatParameter(service, 0, CFSTR("brightness"), &brightness);
        IOObjectRelease(service);
        service = IOIteratorNext(iterator);
    }
    IOObjectRelease(iterator);
    return fmaxf(0, fminf(brightness, 1));
}

static void CMWriteBrightnessFallback(float value) {
    io_iterator_t iterator = IO_OBJECT_NULL;
    kern_return_t result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator);
    if (result != KERN_SUCCESS) {
        return;
    }

    io_service_t service = IOIteratorNext(iterator);
    while (service != IO_OBJECT_NULL) {
        IODisplaySetFloatParameter(service, 0, CFSTR("brightness"), value);
        IOObjectRelease(service);
        service = IOIteratorNext(iterator);
    }
    IOObjectRelease(iterator);
}

NSString * _Nullable CMCurrentTouchBarPresentationMode(void) {
    CFPropertyListRef value = CFPreferencesCopyAppValue(CMKPresentationModeGlobal, CMKTouchBarAgentIdentifier);
    if (value == NULL) {
        return nil;
    }
    id bridged = CFBridgingRelease(value);
    if ([bridged isKindOfClass:[NSString class]]) {
        return bridged;
    }
    return nil;
}

void CMSetTouchBarPresentationMode(NSString *mode) {
    CFPreferencesSetAppValue(CMKPresentationModeGlobal, (__bridge CFStringRef)mode, CMKTouchBarAgentIdentifier);
    CFPreferencesAppSynchronize(CMKTouchBarAgentIdentifier);
}

void CMPresentTouchBarOnTop(NSTouchBar *touchBar, NSInteger placement) {
    if (@available(macOS 10.14, *)) {
        [NSTouchBar presentSystemModalTouchBar:touchBar placement:placement systemTrayItemIdentifier:nil];
    } else {
        [NSTouchBar presentSystemModalFunctionBar:touchBar placement:placement systemTrayItemIdentifier:nil];
    }
}

void CMDismissTouchBarFromTop(NSTouchBar *touchBar) {
    if (@available(macOS 10.14, *)) {
        [NSTouchBar dismissSystemModalTouchBar:touchBar];
    } else {
        [NSTouchBar dismissSystemModalFunctionBar:touchBar];
    }
}

void CMIncreaseBrightness(void) {
    CMSendMediaKeyTap(NX_KEYTYPE_BRIGHTNESS_UP);
}

void CMDecreaseBrightness(void) {
    CMSendMediaKeyTap(NX_KEYTYPE_BRIGHTNESS_DOWN);
}

float CMCurrentBrightness(void) {
    static CMCoreDisplayGetBrightnessFn getBrightness = NULL;
    static CMCoreDisplaySetBrightnessFn setBrightness = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY);
        if (handle != NULL) {
            getBrightness = (CMCoreDisplayGetBrightnessFn)dlsym(handle, "CoreDisplay_Display_GetUserBrightness");
            setBrightness = (CMCoreDisplaySetBrightnessFn)dlsym(handle, "CoreDisplay_Display_SetUserBrightness");
        }
    });

    if (getBrightness != NULL) {
        double brightness = getBrightness(0);
        if (isfinite(brightness)) {
            return (float)fmax(0.0, fmin(brightness, 1.0));
        }
    }

    return CMReadBrightnessFallback();
}

void CMSetBrightness(float value) {
    static CMCoreDisplayGetBrightnessFn getBrightness = NULL;
    static CMCoreDisplaySetBrightnessFn setBrightness = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY);
        if (handle != NULL) {
            getBrightness = (CMCoreDisplayGetBrightnessFn)dlsym(handle, "CoreDisplay_Display_GetUserBrightness");
            setBrightness = (CMCoreDisplaySetBrightnessFn)dlsym(handle, "CoreDisplay_Display_SetUserBrightness");
        }
    });

    float clamped = fmaxf(0, fminf(value, 1));
    if (setBrightness != NULL) {
        setBrightness(0, clamped);
        return;
    }

    CMWriteBrightnessFallback(clamped);
}
