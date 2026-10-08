#import <Cocoa/Cocoa.h>
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        NSString *directory = @(argv[1]);
        [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
        for (NSNumber *base in @[@16, @32, @128, @256, @512]) for (int scale = 1; scale <= 2; scale++) {
            NSInteger pixels = base.integerValue * scale;
            NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:pixels pixelsHigh:pixels bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
            NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
            CGFloat unit = pixels / 512.0;
            [[NSColor colorWithSRGBRed:0.16 green:0.34 blue:0.75 alpha:1] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(20*unit,20*unit,472*unit,472*unit) xRadius:100*unit yRadius:100*unit] fill];
            [NSColor.whiteColor setFill];
            [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(139*unit,68*unit,234*unit,376*unit) xRadius:30*unit yRadius:30*unit] fill];
            [[NSColor colorWithSRGBRed:0.08 green:0.18 blue:0.38 alpha:1] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(153*unit,94*unit,206*unit,328*unit) xRadius:15*unit yRadius:15*unit] fill];
            [@">" drawAtPoint:NSMakePoint(181*unit,183*unit) withAttributes:@{NSFontAttributeName:[NSFont monospacedSystemFontOfSize:130*unit weight:NSFontWeightBold],NSForegroundColorAttributeName:NSColor.whiteColor}];
            NSBezierPath *cursor = [NSBezierPath bezierPathWithRect:NSMakeRect(265*unit,211*unit,55*unit,12*unit)];
            [[NSColor colorWithSRGBRed:0.35 green:0.85 blue:0.71 alpha:1] setFill]; [cursor fill];
            NSString *name = [NSString stringWithFormat:@"icon_%ldx%ld%@.png",(long)base.integerValue,(long)base.integerValue,scale == 2 ? @"@2x" : @""];
            NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            if (![png writeToFile:[directory stringByAppendingPathComponent:name] atomically:YES]) return 1;
        }
    }
    return 0;
}
