#import "VirtualDisplay.h"
#import <signal.h>
#import <unistd.h>
#import <math.h>

static NSString *const ScreenName = @"iPad Portrait Vibe";
static NSString *RunDirectory(void) {
    NSString *override = NSProcessInfo.processInfo.environment[@"IPV_DATA_ROOT"];
    NSString *support = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    NSString *root = override.length ? override : [support stringByAppendingPathComponent:@"iPad Portrait Vibe/01_runs"];
    if (!root.length) return nil;
    NSError *error = nil;
    if (![NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:&error]) return nil;
    NSInteger next = 1;
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:root error:nil])
        next = MAX(next, [[name componentsSeparatedByString:@"_"] firstObject].integerValue + 1);
    // Keep every run separate and never reuse an earlier run directory.
    NSString *path = [root stringByAppendingPathComponent:[NSString stringWithFormat:@"%02ld_%@", (long)next, NSUUID.UUID.UUIDString]];
    if (![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error]) return nil;
    return path;
}
static NSString *JSONText(id value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingSortedKeys error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"{}";
}
static void Emit(NSDictionary *event) { puts(JSONText(event).UTF8String); fflush(stdout); }
static NSString *DisplayUUID(CGDirectDisplayID display) {
    CFUUIDRef uuid = CGDisplayCreateUUIDFromDisplayID(display);
    if (!uuid) return @"";
    NSString *value = CFBridgingRelease(CFUUIDCreateString(NULL, uuid));
    CFRelease(uuid); return value;
}
static NSDictionary *ModeInfo(CGDisplayModeRef mode) {
    if (!mode) return @{};
    return @{ @"width": @(CGDisplayModeGetWidth(mode)), @"height": @(CGDisplayModeGetHeight(mode)),
              @"pixelWidth": @(CGDisplayModeGetPixelWidth(mode)), @"pixelHeight": @(CGDisplayModeGetPixelHeight(mode)),
              @"modeID": @(CGDisplayModeGetIODisplayModeID(mode)), @"refreshRate": @(CGDisplayModeGetRefreshRate(mode)) };
}
static NSDictionary *MirrorModeInfo(CGDirectDisplayID source, CGDirectDisplayID physical) {
    CGDisplayModeRef mode = CGDisplayCopyDisplayMode(source);
    // Some WindowServer versions omit the mirror-source mode. The mirrored
    // physical display must expose the same effective framebuffer dimensions.
    if (!mode && CGDisplayMirrorsDisplay(physical) == source)
        mode = CGDisplayCopyDisplayMode(physical);
    NSDictionary *info = ModeInfo(mode);
    if (mode) CFRelease(mode);
    return info;
}
static BOOL RetinaMode(NSDictionary *info) {
    return [info[@"width"] unsignedIntValue] == 744 && [info[@"height"] unsignedIntValue] == 1134 &&
           [info[@"pixelWidth"] unsignedIntValue] == 1488 && [info[@"pixelHeight"] unsignedIntValue] == 2268;
}
static NSArray *Displays(void) {
    CGDirectDisplayID ids[32]; uint32_t count = 0;
    if (CGGetOnlineDisplayList(32, ids, &count) != kCGErrorSuccess) return @[];
    NSMutableArray *result = [NSMutableArray array];
    for (uint32_t i = 0; i < count; ++i) {
        CGDirectDisplayID d = ids[i]; CGRect bounds = CGDisplayBounds(d);
        CGDisplayModeRef mode = CGDisplayCopyDisplayMode(d);
        [result addObject:@{ @"id": @(d), @"uuid": DisplayUUID(d), @"builtin": @(CGDisplayIsBuiltin(d)),
                            @"mirrorOf": @(CGDisplayMirrorsDisplay(d)), @"main": @(d == CGMainDisplayID()),
                            @"x": @(bounds.origin.x), @"y": @(bounds.origin.y),
                            @"boundsWidth": @(bounds.size.width), @"boundsHeight": @(bounds.size.height),
                            @"mode": ModeInfo(mode) }];
        if (mode) CFRelease(mode);
    }
    return result;
}
static BOOL SameMode(NSDictionary *a, NSDictionary *b) {
    for (NSString *key in @[@"width", @"height", @"pixelWidth", @"pixelHeight"])
        if (![a[key] isEqual:b[key]]) return NO;
    return fabs([a[@"refreshRate"] doubleValue] - [b[@"refreshRate"] doubleValue]) < 0.1;
}
static CGDirectDisplayID FindDisplay(NSDictionary *saved) {
    for (NSDictionary *d in Displays())
        if ([d[@"uuid"] isEqual:saved[@"uuid"]]) return [d[@"id"] unsignedIntValue];
    return 0;
}
static CGDisplayModeRef FindMode(CGDirectDisplayID d, NSDictionary *saved) {
    CFArrayRef modes = CGDisplayCopyAllDisplayModes(d, (__bridge CFDictionaryRef)@{(__bridge NSString *)kCGDisplayShowDuplicateLowResolutionModes: @YES});
    CGDisplayModeRef chosen = NULL;
    for (id item in (__bridge NSArray *)modes) {
        CGDisplayModeRef mode = (__bridge CGDisplayModeRef)item;
        NSDictionary *info = ModeInfo(mode);
        if (SameMode(info, saved)) {
            chosen = mode;
            if ([info[@"modeID"] isEqual:saved[@"modeID"]]) break;
        }
    }
    if (chosen) CFRetain(chosen);
    if (modes) CFRelease(modes); return chosen;
}
static BOOL Restore(NSDictionary *saved, NSString **detail) {
    CGDirectDisplayID d = FindDisplay(saved);
    if (!d) { if (detail) *detail = @"原显示器已断开，无法恢复它的设置。"; return NO; }
    CGDisplayModeRef mode = FindMode(d, saved[@"mode"]);
    if (!mode) { if (detail) *detail = @"系统没有提供原来的显示模式。"; return NO; }
    CGDisplayConfigRef config = NULL; CGError error = CGBeginDisplayConfiguration(&config);
    if (!error) error = CGConfigureDisplayMirrorOfDisplay(config, d, kCGNullDirectDisplay);
    if (!error) error = CGConfigureDisplayOrigin(config, d, [saved[@"x"] intValue], [saved[@"y"] intValue]);
    if (!error) error = CGConfigureDisplayWithDisplayMode(config, d, mode, NULL);
    if (!error) error = CGCompleteDisplayConfiguration(config, kCGConfigureForAppOnly);
    else if (config) CGCancelDisplayConfiguration(config);
    CFRelease(mode);
    if (detail) *detail = error ? [NSString stringWithFormat:@"恢复请求返回错误 %d。", error] : @"恢复请求已提交。";
    return error == kCGErrorSuccess;
}
static BOOL Restored(NSDictionary *saved) {
    for (NSDictionary *d in Displays())
        if ([d[@"uuid"] isEqual:saved[@"uuid"]])
            return SameMode(d[@"mode"], saved[@"mode"]) && [d[@"mirrorOf"] unsignedIntValue] == 0 &&
                   [d[@"x"] isEqual:saved[@"x"]] && [d[@"y"] isEqual:saved[@"y"]] && [d[@"main"] boolValue];
    return NO;
}
static BOOL VirtualAPIAvailable(void) {
    NSDictionary *requirements = @{
        @"CGVirtualDisplayDescriptor": @[@"setName:", @"setQueue:", @"setVendorID:", @"setProductID:", @"setSerialNum:", @"setMaxPixelsWide:", @"setMaxPixelsHigh:", @"setSizeInMillimeters:", @"setRedPrimary:", @"setGreenPrimary:", @"setBluePrimary:", @"setWhitePoint:"],
        @"CGVirtualDisplaySettings": @[@"setModes:", @"setHiDPI:"],
        @"CGVirtualDisplayMode": @[@"initWithWidth:height:refreshRate:"],
        @"CGVirtualDisplay": @[@"initWithDescriptor:", @"applySettings:", @"displayID"]
    };
    for (NSString *name in requirements) {
        Class c = NSClassFromString(name); if (!c) return NO;
        for (NSString *selector in requirements[name])
            if (![c instancesRespondToSelector:NSSelectorFromString(selector)]) return NO;
    }
    return YES;
}
static NSDictionary *Probe(void) {
    NSMutableArray *screens = [NSMutableArray array];
    for (NSScreen *screen in NSScreen.screens)
        [screens addObject:@{ @"name": screen.localizedName, @"frame": NSStringFromRect(screen.frame), @"scale": @(screen.backingScaleFactor) }];
    return @{ @"displays": Displays(), @"virtualAPIAvailable": @(VirtualAPIAvailable()),
              @"virtualMaximumPixels": @[@1488, @2268], @"requestedDesktop": @[@744, @1134],
              @"os": NSProcessInfo.processInfo.operatingSystemVersionString, @"screens": screens };
}

@interface DisplaySession : NSObject
@property(strong) IPVirtualDisplay *virtualDisplay;
@property(strong) NSDictionary *saved;
@property(strong) NSString *directory;
@property(strong) NSTimer *timer;
@property(strong) NSDate *deadline;
@property BOOL finishing;
@property pid_t parentPID;
- (void)finish:(NSString *)reason;
@end
@implementation DisplaySession
- (void)record:(NSDictionary *)event {
    Emit(event);
    NSString *line = [JSONText(event) stringByAppendingString:@"\n"];
    NSString *path = [self.directory stringByAppendingPathComponent:@"events.jsonl"];
    if (![NSFileManager.defaultManager fileExistsAtPath:path])
        [NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    [file seekToEndOfFile]; [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile];
}
- (void)finish:(NSString *)reason {
    if (self.finishing) return; self.finishing = YES; [self.timer invalidate];
    NSString *detail = @""; BOOL submitted = Restore(self.saved, &detail);
    // A helper process owns the private virtual display. Exiting is the
    // reliable disconnect mechanism, including macOS versions that retain it.
    [self record:@{ @"event": @"restoring", @"reason": reason, @"submitted": @(submitted), @"detail": detail }];
    [NSFileHandle.fileHandleWithStandardInput setReadabilityHandler:nil];
    exit(submitted ? 0 : 3);
}
@end

static int Helper(NSString *directory, double seconds) {
    signal(SIGPIPE, SIG_IGN);
    // The helper holds the virtual display but never owns a user interface.
    // LSUIElement also prevents a transient Dock icon before main() starts.
    [NSApplication.sharedApplication setActivationPolicy:NSApplicationActivationPolicyProhibited];
    NSDictionary *probe = Probe(); NSArray *displays = probe[@"displays"];
    if (displays.count != 1 || [displays[0][@"mirrorOf"] unsignedIntValue] != 0 || ![displays[0][@"main"] boolValue]) {
        Emit(@{ @"event": @"error", @"message": @"当前版本支持一块未开启镜像的显示器。请断开额外显示器后重试。", @"probe": probe }); return 2;
    }
    if (!VirtualAPIAvailable()) { Emit(@{ @"event": @"error", @"message": @"当前 macOS 不提供需要的虚拟屏幕接口。" }); return 2; }
    if (![displays[0][@"uuid"] length] || ![displays[0][@"mode"] count]) {
        Emit(@{ @"event": @"error", @"message": @"无法读取可恢复的原显示设置，已取消切换。" }); return 2;
    }
    DisplaySession *session = [DisplaySession new]; session.directory = directory;
    session.saved = displays[0]; session.parentPID = getppid(); session.deadline = [NSDate dateWithTimeIntervalSinceNow:seconds];
    if (![session.saved writeToFile:[directory stringByAppendingPathComponent:@"original-display.plist"] atomically:YES]) {
        Emit(@{ @"event": @"error", @"message": @"无法保存原显示设置，已取消切换。" }); return 2;
    }
    // Arm recovery before any display is created or reconfigured.
    session.timer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *t) {
        if (getppid() != session.parentPID) [session finish:@"parent-exited"];
        if (session.deadline && [session.deadline timeIntervalSinceNow] <= 0) [session finish:@"timeout"];
    }];
    IPVirtualDescriptor *descriptor = [[NSClassFromString(@"CGVirtualDisplayDescriptor") alloc] init];
    descriptor.name = ScreenName; descriptor.queue = dispatch_get_main_queue();
    descriptor.vendorID = 0x4A48; descriptor.productID = 0x0701; descriptor.serialNum = 70001;
    if ([descriptor respondsToSelector:NSSelectorFromString(@"setSerialNumber:")])
        [descriptor setValue:@70001 forKey:@"serialNumber"];
    descriptor.maxPixelsWide = 1488; descriptor.maxPixelsHigh = 2268;
    descriptor.sizeInMillimeters = CGSizeMake(116.0, 176.6);
    descriptor.redPrimary = CGPointMake(0.64, 0.33); descriptor.greenPrimary = CGPointMake(0.30, 0.60);
    descriptor.bluePrimary = CGPointMake(0.15, 0.06); descriptor.whitePoint = CGPointMake(0.3127, 0.3290);
    session.virtualDisplay = [[NSClassFromString(@"CGVirtualDisplay") alloc] initWithDescriptor:descriptor];
    if (!session.virtualDisplay) {
        [session record:@{ @"event": @"error", @"message": @"macOS 未能创建虚拟屏幕。" }]; [session finish:@"creation-failed"];
    }
    IPVirtualSettings *settings = [[NSClassFromString(@"CGVirtualDisplaySettings") alloc] init];
    settings.hiDPI = 1;
    // A HiDPI virtual mode takes desktop points, while the descriptor takes
    // maximum framebuffer pixels. Passing pixels here prevents the 2x mode.
    IPVirtualMode *mode = [[NSClassFromString(@"CGVirtualDisplayMode") alloc] initWithWidth:744 height:1134 refreshRate:60];
    settings.modes = @[mode];
    if (![session.virtualDisplay applySettings:settings]) {
        [session record:@{ @"event": @"error", @"message": @"macOS 拒绝了竖屏分辨率。" }]; [session finish:@"settings-failed"];
    }
    CGDirectDisplayID virtualID = session.virtualDisplay.displayID;
    // WindowServer registers the display asynchronously. Pump the run loop
    // briefly, keeping the watchdog armed, before requesting mirroring.
    NSDate *registrationLimit = [NSDate dateWithTimeIntervalSinceNow:4];
    while (!CGDisplayIsOnline(virtualID) && registrationLimit.timeIntervalSinceNow > 0)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    if (!virtualID || !CGDisplayIsOnline(virtualID)) {
        [session record:@{ @"event": @"error", @"message": @"虚拟屏幕未在规定时间内上线。" }]; [session finish:@"registration-failed"];
    }
    CGDirectDisplayID physicalID = [session.saved[@"id"] unsignedIntValue];
    [session record:@{ @"event": @"virtual-created", @"probe": Probe() }];
    CGDisplayConfigRef config = NULL; CGError error = CGBeginDisplayConfiguration(&config);
    if (!error) error = CGConfigureDisplayOrigin(config, virtualID, 0, 0);
    if (!error) error = CGConfigureDisplayMirrorOfDisplay(config, physicalID, virtualID);
    if (!error) error = CGCompleteDisplayConfiguration(config, kCGConfigureForAppOnly);
    else if (config) CGCancelDisplayConfiguration(config);
    if (error) {
        [session record:@{ @"event": @"error", @"message": [NSString stringWithFormat:@"macOS 无法将桌面镜像到竖屏，错误 %d。", error] }];
        [session finish:@"mirror-failed"];
    }
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    NSMutableArray *mirrorModes = [NSMutableArray array];
    CFArrayRef mirrorModeList = CGDisplayCopyAllDisplayModes(virtualID, (__bridge CFDictionaryRef)@{(__bridge NSString *)kCGDisplayShowDuplicateLowResolutionModes: @YES});
    CGDisplayModeRef preferred = NULL;
    for (id item in (__bridge NSArray *)mirrorModeList) {
        CGDisplayModeRef m = (__bridge CGDisplayModeRef)item; [mirrorModes addObject:ModeInfo(m)];
        if (RetinaMode(ModeInfo(m))) {
            if (!preferred || CGDisplayModeGetPixelWidth(m) > CGDisplayModeGetPixelWidth(preferred)) preferred = m;
        }
    }
    if (!preferred) {
        if (mirrorModeList) CFRelease(mirrorModeList);
        [session record:@{ @"event": @"error", @"message": @"系统没有提供所需的 Retina 高清模式，正在恢复。" }];
        [session finish:@"retina-mode-unavailable"];
    }
    if (preferred) {
        CGDisplayConfigRef retinaConfig = NULL; CGError retinaError = CGBeginDisplayConfiguration(&retinaConfig);
        if (!retinaError) retinaError = CGConfigureDisplayWithDisplayMode(retinaConfig, virtualID, preferred, NULL);
        if (!retinaError) retinaError = CGCompleteDisplayConfiguration(retinaConfig, kCGConfigureForAppOnly);
        else if (retinaConfig) CGCancelDisplayConfiguration(retinaConfig);
        [session record:@{ @"event": @"readable-scale-request", @"error": @(retinaError) }];
    }
    if (mirrorModeList) CFRelease(mirrorModeList);
    [session record:@{ @"event": @"mirror-modes", @"modes": mirrorModes }];
    // WindowServer notifies clients after a successful configuration call.
    // Wait for the observed geometry, rather than trusting its return code.
    NSDate *geometryLimit = [NSDate dateWithTimeIntervalSinceNow:3];
    while (geometryLimit.timeIntervalSinceNow > 0) {
        CGRect observed = CGDisplayBounds(virtualID);
        if (observed.size.width == 744 && observed.size.height == 1134 &&
            RetinaMode(MirrorModeInfo(virtualID, physicalID))) break;
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    NSDictionary *actual = MirrorModeInfo(virtualID, physicalID);
    // Geometry alone can match a low-resolution mode. Require the actual
    // 2x framebuffer as well before reporting a successful switch.
    CGRect effectiveBounds = CGDisplayBounds(virtualID);
    BOOL portrait = effectiveBounds.size.width == 744 && effectiveBounds.size.height == 1134;
    if (!portrait || !RetinaMode(actual) || CGDisplayMirrorsDisplay(physicalID) != virtualID) {
        [session record:@{ @"event": @"error", @"message": @"系统没有实际进入 Retina 高清竖屏状态，正在恢复。", @"displays": Displays() }];
        [session finish:@"verification-failed"];
    }
    [session record:@{ @"event": @"ready", @"helperActivationPolicy": @(NSApp.activationPolicy), @"virtualDisplayID": @(virtualID), @"physicalDisplayID": @(physicalID),
                       @"seconds": @(MAX(0, session.deadline.timeIntervalSinceNow)), @"mode": actual, @"pixelScale": @2, @"displays": Displays(), @"probe": Probe() }];
    NSMutableData *buffer = [NSMutableData data];
    NSFileHandle.fileHandleWithStandardInput.readabilityHandler = ^(NSFileHandle *handle) {
        NSData *data = handle.availableData;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!data.length) { [session finish:@"control-pipe-closed"]; return; }
            [buffer appendData:data];
            while (YES) {
                const char *bytes = buffer.bytes; NSUInteger length = buffer.length, end = 0;
                while (end < length && bytes[end] != '\n') end++;
                if (end == length) break;
                NSString *command = [[NSString alloc] initWithBytes:bytes length:end encoding:NSUTF8StringEncoding];
                [buffer replaceBytesInRange:NSMakeRange(0, end + 1) withBytes:NULL length:0];
                if ([command isEqual:@"keep"]) { session.deadline = nil; [session record:@{ @"event": @"kept" }]; }
                else if ([command isEqual:@"stop"]) [session finish:@"user-request"];
            }
        });
    };
    [NSRunLoop.currentRunLoop run]; return 0;
}

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(strong) NSWindow *window;
@property(strong) NSButton *toggle, *keep;
@property(strong) NSTextField *status, *countdown;
@property(strong) NSStatusItem *statusItem;
@property(strong) NSTask *task;
@property(strong) NSPipe *control, *output;
@property(strong) NSMutableData *buffer;
@property(strong) NSTimer *ticker;
@property(strong) NSDate *deadline;
@property(strong) NSString *directory;
@property(strong) NSDictionary *original;
@property(strong) NSString *lastError;
@property BOOL ready, busy, kept, quitting;
@end
@implementation AppDelegate
- (NSTextField *)label:(NSString *)text size:(CGFloat)size frame:(NSRect)frame {
    NSTextField *label = [NSTextField wrappingLabelWithString:text]; label.frame = frame;
    label.font = [NSFont systemFontOfSize:size]; label.alignment = NSTextAlignmentCenter;
    [self.window.contentView addSubview:label]; return label;
}
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    signal(SIGPIPE, SIG_IGN);
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 430, 450)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"iPad Portrait Vibe"; self.window.delegate = self; self.window.releasedWhenClosed = NO;
    [self label:@"▯" size:68 frame:NSMakeRect(165, 338, 100, 90)];
    [self label:@"iPad Portrait Vibe" size:23 frame:NSMakeRect(25, 305, 380, 35)];
    [self label:@"Retina 高清竖屏 · 用 iPad 远控 Mac 做 Vibe Coding" size:14 frame:NSMakeRect(25, 270, 380, 28)];
    self.toggle = [NSButton buttonWithTitle:@"切换到 iPad 竖屏" target:self action:@selector(toggleMode:)];
    self.toggle.frame = NSMakeRect(65, 203, 300, 52); self.toggle.bezelStyle = NSBezelStyleRounded;
    self.toggle.font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold]; self.toggle.keyEquivalent = @"\r";
    [self.window.contentView addSubview:self.toggle];
    self.status = [self label:@"当前是正常电脑模式" size:14 frame:NSMakeRect(30, 145, 370, 52)];
    self.countdown = [self label:@"试切换后，120 秒内未确认会自动恢复。" size:12 frame:NSMakeRect(25, 114, 380, 25)];
    self.keep = [NSButton buttonWithTitle:@"画面正常，保持竖屏" target:self action:@selector(keepMode:)];
    self.keep.frame = NSMakeRect(105, 66, 220, 36); self.keep.bezelStyle = NSBezelStyleRounded; self.keep.hidden = YES;
    [self.window.contentView addSubview:self.keep];
    [self label:@"UU 中如仍看到横屏，请选择「iPad Portrait Vibe」。" size:11 frame:NSMakeRect(20, 15, 390, 36)];
    NSMenu *appMenu = [NSMenu new];
    [appMenu addItemWithTitle:@"恢复并退出" action:@selector(quit:) keyEquivalent:@"q"];
    NSMenu *bar = [NSMenu new]; NSMenuItem *root = [NSMenuItem new]; root.submenu = appMenu; [bar addItem:root]; NSApp.mainMenu = bar;
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength]; self.statusItem.button.title = @"▯ iPad";
    NSMenu *menu = [NSMenu new];
    [menu addItemWithTitle:@"显示开关窗口" action:@selector(showWindow:) keyEquivalent:@""];
    [menu addItemWithTitle:@"切换 / 恢复" action:@selector(toggleMode:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"恢复并退出" action:@selector(quit:) keyEquivalent:@""];
    self.statusItem.menu = menu;
    for (NSMenuItem *item in appMenu.itemArray) item.target = self;
    for (NSMenuItem *item in menu.itemArray) item.target = self;
    if (Displays().count != 1) self.status.stringValue = @"检测到多块或镜像屏幕。请恢复单屏后再切换。";
    [self.window center]; [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
}
- (void)showWindow:(id)sender { [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES]; }
- (NSString *)newRunDirectory {
    return RunDirectory();
}
- (void)send:(NSString *)command {
    @try { [self.control.fileHandleForWriting writeData:[[command stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]]; }
    @catch (NSException *exception) { self.lastError = @"竖屏进程已经结束，正在检查恢复情况。"; }
}
- (void)toggleMode:(id)sender {
    if (self.busy) return;
    if (self.ready && !self.task.running) return;
    if (self.task.running) {
        self.busy = YES; self.toggle.enabled = NO; self.keep.hidden = YES; self.status.stringValue = @"正在恢复原来的显示设置…";
        [self send:@"stop"]; return;
    }
    NSArray *displays = Displays();
    if (displays.count != 1) { self.status.stringValue = @"当前版本支持一块屏幕。请断开额外显示器后重试。"; return; }
    self.original = displays[0]; self.directory = [self newRunDirectory];
    if (!self.directory) { self.status.stringValue = @"无法保存本地恢复记录，已取消切换。"; return; }
    self.busy = YES; self.ready = NO; self.kept = NO; self.lastError = nil; self.toggle.enabled = NO;
    self.status.stringValue = @"正在创建竖屏桌面…"; self.buffer = [NSMutableData data];
    self.task = [NSTask new]; self.task.executableURL = [NSURL fileURLWithPath:NSBundle.mainBundle.executablePath];
    self.task.arguments = @[@"--helper", self.directory, @"120"];
    self.control = [NSPipe pipe]; self.output = [NSPipe pipe];
    self.task.standardInput = self.control; self.task.standardOutput = self.output;
    NSString *stderrPath = [self.directory stringByAppendingPathComponent:@"system.log"];
    [NSFileManager.defaultManager createFileAtPath:stderrPath contents:nil attributes:nil];
    self.task.standardError = [NSFileHandle fileHandleForWritingAtPath:stderrPath];
    NSTask *launchedTask = self.task;
    __weak AppDelegate *weakSelf = self;
    self.output.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
        NSData *data = handle.availableData;
        if (!data.length) { handle.readabilityHandler = nil; return; }
        dispatch_async(dispatch_get_main_queue(), ^{ if (weakSelf.task == launchedTask) [weakSelf consume:data]; });
    };
    self.task.terminationHandler = ^(NSTask *task) {
        dispatch_async(dispatch_get_main_queue(), ^{ if (weakSelf.task == task) [weakSelf ended:task.terminationStatus]; });
    };
    NSError *error = nil;
    if (![self.task launchAndReturnError:&error]) {
        self.lastError = error.localizedDescription; [self ended:2]; return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 12 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (weakSelf.task == launchedTask && weakSelf.busy && !weakSelf.ready && launchedTask.running) {
            weakSelf.lastError = @"系统响应超时，正在自动恢复。"; [weakSelf send:@"stop"];
        }
    });
}
- (void)consume:(NSData *)data {
    [self.buffer appendData:data];
    while (YES) {
        const char *bytes = self.buffer.bytes; NSUInteger end = 0, length = self.buffer.length;
        while (end < length && bytes[end] != '\n') end++; if (end == length) break;
        NSData *line = [NSData dataWithBytes:bytes length:end];
        [self.buffer replaceBytesInRange:NSMakeRange(0, end + 1) withBytes:NULL length:0];
        NSDictionary *event = [NSJSONSerialization JSONObjectWithData:line options:0 error:nil];
        if ([event[@"event"] isEqual:@"ready"]) {
            self.ready = YES; self.busy = NO; self.toggle.enabled = YES; self.toggle.title = @"恢复正常电脑模式";
            self.status.stringValue = @"已进入 Retina 高清竖屏（2×）。\n请在 iPad 上检查清晰度和点击位置。"; self.keep.hidden = NO;
            // The helper owns the authoritative recovery deadline.
            self.deadline = [NSDate dateWithTimeIntervalSinceNow:[event[@"seconds"] doubleValue]];
            [self.window center]; [self showWindow:nil];
            self.ticker = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
            [self tick:nil];
        } else if ([event[@"event"] isEqual:@"error"]) self.lastError = event[@"message"];
        else if ([event[@"event"] isEqual:@"kept"]) {
            self.kept = YES; self.keep.hidden = YES; [self.ticker invalidate];
            self.countdown.stringValue = @"再次点击上方按钮即可恢复。关闭程序也会恢复。";
        }
    }
}
- (void)tick:(NSTimer *)timer {
    NSInteger left = MAX(0, (NSInteger)ceil(self.deadline.timeIntervalSinceNow));
    self.countdown.stringValue = [NSString stringWithFormat:@"%ld 秒后自动恢复；画面正常可点击下方确认。", (long)left];
}
- (void)keepMode:(id)sender { if (self.ready && self.task.running) [self send:@"keep"]; }
- (void)ended:(int)code {
    self.busy = YES; self.toggle.enabled = NO;
    [self.ticker invalidate]; self.output.fileHandleForReading.readabilityHandler = nil;
    [self.control.fileHandleForWriting closeFile];
    [self checkRestoration:code deadline:[NSDate dateWithTimeIntervalSinceNow:5] retried:NO];
}
- (void)checkRestoration:(int)code deadline:(NSDate *)deadline retried:(BOOL)retried {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        BOOL restored = self.original && Restored(self.original) && Displays().count == 1; NSString *detail = @"";
        BOOL didRetry = retried;
        if (!restored && !retried && deadline.timeIntervalSinceNow < 4 && self.original) {
            Restore(self.original, &detail); didRetry = YES;
        }
        if (!restored && deadline.timeIntervalSinceNow > 0) {
            [self checkRestoration:code deadline:deadline retried:didRetry]; return;
        }
        NSDictionary *result = @{ @"restored": @(restored), @"helperExit": @(code), @"displays": Displays(),
                                  @"error": self.lastError ?: @"", @"detail": detail };
        [JSONText(result) writeToFile:[self.directory stringByAppendingPathComponent:@"result.json"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        self.busy = NO; self.ready = NO; self.toggle.enabled = YES; self.toggle.title = @"切换到 iPad 竖屏"; self.keep.hidden = YES;
        self.status.stringValue = self.lastError ?: (restored ? @"已恢复原来的显示设置" : @"未确认恢复成功，请打开系统设置 → 显示器检查。" );
        self.countdown.stringValue = @"试切换后，120 秒内未确认会自动恢复。";
        [self.window center];
        if (self.quitting) [NSApp terminate:nil];
    });
}
- (void)quit:(id)sender {
    self.quitting = YES;
    if (self.task.running) { self.status.stringValue = @"正在恢复后退出…"; [self send:@"stop"]; }
    else [NSApp terminate:nil];
}
- (BOOL)windowShouldClose:(NSWindow *)sender { [self quit:nil]; return NO; }
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    if (self.task.running) { [self quit:nil]; return NSTerminateCancel; } return NSTerminateNow;
}
@end

static int Smoke(NSString *directory, double seconds, BOOL keep, BOOL abrupt) {
    signal(SIGPIPE, SIG_IGN);
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray *before = Displays();
    if (before.count != 1) { Emit(@{ @"error": @"smoke_requires_one_display", @"before": before }); return 2; }
    NSTask *task = [NSTask new]; task.executableURL = [NSURL fileURLWithPath:NSProcessInfo.processInfo.arguments[0]];
    task.arguments = @[@"--helper", directory, [NSString stringWithFormat:@"%.1f", seconds]];
    NSPipe *input = [NSPipe pipe]; NSPipe *output = [NSPipe pipe]; task.standardInput = input; task.standardOutput = output;
    NSError *error = nil;
    if (![task launchAndReturnError:&error]) { Emit(@{ @"error": error.localizedDescription }); return 2; }
    if (keep) {
        // Exercise confirmation followed by explicit restore; schedule it only
        // after READY so it tests the real child control protocol.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            usleep(2000000); [input.fileHandleForWriting writeData:[@"keep\n" dataUsingEncoding:NSUTF8StringEncoding]];
            usleep((useconds_t)((seconds + 1) * 1000000));
            [input.fileHandleForWriting writeData:[@"stop\n" dataUsingEncoding:NSUTF8StringEncoding]];
        });
    } else if (abrupt) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            usleep(3000000); [input.fileHandleForWriting closeFile];
        });
    }
    [task waitUntilExit]; NSData *events = [output.fileHandleForReading readDataToEndOfFile];
    NSString *lines = [[NSString alloc] initWithData:events encoding:NSUTF8StringEncoding]; if (lines) fputs(lines.UTF8String, stdout);
    for (int i = 0; i < 30 && !Restored(before[0]); ++i) usleep(100000);
    BOOL ready = [lines containsString:@"\"event\":\"ready\""];
    BOOL restored = Restored(before[0]); NSArray *after = Displays();
    NSDictionary *result = @{ @"enteredPortrait": @(ready), @"restored": @(restored), @"helperExit": @(task.terminationStatus),
                              @"before": before, @"after": after, @"virtualRemoved": @(after.count == before.count),
                              @"kept": @([lines containsString:@"\"event\":\"kept\""]) };
    [JSONText(result) writeToFile:[directory stringByAppendingPathComponent:@"result.json"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    Emit(result); return ready && restored && after.count == before.count && task.terminationStatus == 0 ? 0 : 1;
}
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSArray<NSString *> *args = NSProcessInfo.processInfo.arguments;
        if (args.count > 1 && [args[1] isEqual:@"--probe"]) { Emit(Probe()); return 0; }
        if (args.count > 1 && [args[1] isEqual:@"--check-storage"]) {
            NSString *path = RunDirectory(); Emit(@{ @"writable": @(path != nil), @"directory": path ?: @"" }); return path ? 0 : 2;
        }
        if (args.count > 3 && [args[1] isEqual:@"--helper"]) return Helper(args[2], MAX(5, [args[3] doubleValue]));
        if (args.count > 3 && [args[1] isEqual:@"--smoke"])
            return Smoke(args[2], MAX(5, [args[3] doubleValue]), [args containsObject:@"--keep"], [args containsObject:@"--close-pipe"]);
        NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
        for (NSRunningApplication *app in [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleID]) {
            if (app.processIdentifier != getpid() && app.activationPolicy == NSApplicationActivationPolicyRegular) {
                [app activateWithOptions:NSApplicationActivateAllWindows]; return 0;
            }
        }
        [NSApplication sharedApplication]; NSApp.activationPolicy = NSApplicationActivationPolicyRegular;
        AppDelegate *delegate = [AppDelegate new]; NSApp.delegate = delegate; [NSApp run];
    }
    return 0;
}
