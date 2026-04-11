#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

NSString * _Nullable CMCurrentTouchBarPresentationMode(void);
void CMSetTouchBarPresentationMode(NSString *mode);
void CMPresentTouchBarOnTop(NSTouchBar *touchBar, NSInteger placement);
void CMDismissTouchBarFromTop(NSTouchBar *touchBar);

NS_ASSUME_NONNULL_END
