#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>

static BOOL checkedLifetime = NO;

static void requireCompletedCheck(void) {
    if (!checkedLifetime) {
        fputs("FAIL: helper exited before the run-loop lifetime check.\n", stderr);
        _Exit(1);
    }
}

@interface NSXPCListener (HelperLifetimeProbe)
- (instancetype)initForHelperLifetimeProbeWithMachServiceName:(NSString *)name;
- (void)resumeForHelperLifetimeProbe;
@end

@implementation NSXPCListener (HelperLifetimeProbe)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)initForHelperLifetimeProbeWithMachServiceName:(NSString *)name {
    // Use a real anonymous listener without registration or administrator rights.
    self = [NSXPCListener anonymousListener];
    return self;
}
#pragma clang diagnostic pop

- (void)resumeForHelperLifetimeProbe {
    // Retain the listener, but leave ownership of its weak delegate to the helper.
    NSXPCListener *listener = self;
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopDefaultMode, ^{
        checkedLifetime = YES;
        if (listener.delegate == nil) {
            fputs("FAIL: helper lost its XPC delegate before the service loop.\n", stderr);
            exit(1);
        }
        puts("PASS: optimized helper retains its XPC delegate in the service loop.");
        exit(0);
    });
    [self resumeForHelperLifetimeProbe];
}
@end

__attribute__((constructor)) static void installLifetimeProbe(void) {
    atexit(requireCompletedCheck);
    method_exchangeImplementations(
        class_getInstanceMethod(NSXPCListener.class, @selector(initWithMachServiceName:)),
        class_getInstanceMethod(NSXPCListener.class, @selector(initForHelperLifetimeProbeWithMachServiceName:))
    );
    method_exchangeImplementations(
        class_getInstanceMethod(NSXPCListener.class, @selector(resume)),
        class_getInstanceMethod(NSXPCListener.class, @selector(resumeForHelperLifetimeProbe))
    );
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        fputs("FAIL: helper did not reach the run-loop lifetime check.\n", stderr);
        _Exit(1);
    });
}
