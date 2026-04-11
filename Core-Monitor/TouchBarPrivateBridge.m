#import "TouchBarPrivateBridge.h"
#import <CoreFoundation/CoreFoundation.h>

static CFStringRef const CMKPresentationModeGlobal = CFSTR("PresentationModeGlobal");
static CFStringRef const CMKTouchBarAgentIdentifier = CFSTR("com.apple.touchbar.agent");

@interface NSTouchBar (CoreMonitorPrivate)
+ (void)presentSystemModalFunctionBar:(nullable NSTouchBar *)touchBar placement:(long long)placement systemTrayItemIdentifier:(nullable NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalFunctionBar:(nullable NSTouchBar *)touchBar;
+ (void)presentSystemModalTouchBar:(nullable NSTouchBar *)touchBar placement:(long long)placement systemTrayItemIdentifier:(nullable NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalTouchBar:(nullable NSTouchBar *)touchBar;
@end

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
