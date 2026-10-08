#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

// Runtime-only interfaces. These classes are private to macOS; fail closed
// if a required class or selector is unavailable. No third-party dependency.
@interface IPVirtualDescriptor : NSObject
@property(strong) NSString *name;
@property(strong) id queue;
@property unsigned int vendorID, productID, serialNum;
@property unsigned int maxPixelsWide, maxPixelsHigh;
@property CGSize sizeInMillimeters;
@property CGPoint redPrimary, greenPrimary, bluePrimary, whitePoint;
@end
@interface IPVirtualSettings : NSObject
@property(strong) NSArray *modes;
@property unsigned int hiDPI;
@end
@interface IPVirtualMode : NSObject
- (instancetype)initWithWidth:(unsigned int)width height:(unsigned int)height refreshRate:(double)rate;
@end
@interface IPVirtualDisplay : NSObject
- (instancetype)initWithDescriptor:(id)descriptor;
- (BOOL)applySettings:(id)settings;
@property(readonly) unsigned int displayID;
@end
