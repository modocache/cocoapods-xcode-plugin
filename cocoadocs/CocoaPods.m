//
//  Cocoadocs.m
//
//  Copyright (c) 2013 Delisa Mason. http://delisa.me
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.

#import "CocoaPods.h"
#import "CocoaPodsFileManager.h"

static NSString *DMMCocoaPodsIntegrateWithDocsKey = @"DMMCocoaPodsIntegrateWithDocs";
static NSString *RELATIVE_DOCSET_PATH  = @"/Library/Developer/Shared/Documentation/DocSets/";
static NSString *DOCSET_ARCHIVE_FORMAT = @"http://cocoadocs.org/docsets/%@/docset.xar";
static NSString *XAR_EXECUTABLE = @"/usr/bin/xar";


@interface CocoaPods ()
@property (nonatomic, strong) NSMenuItem *installPodsItem;
@property (nonatomic, strong) NSMenuItem *editPodfileItem;
@property (nonatomic, strong) NSMenuItem *installDocsItem;
@end


@implementation CocoaPods

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlugin = [[self alloc] init];
    });
}

+ (NSString *)docsetInstallPath {
    return [NSString pathWithComponents:@[NSHomeDirectory(), RELATIVE_DOCSET_PATH]];
}

- (id)init {
    if (self = [super init]) {
        [self addMenuItems];
    }
    return self;
}

- (void)installOrUpdateDocSetsForPods {
    for (NSString *podName in [CocoaPodsFileManager installedPodNamesInWorkspace]) {
        NSURL *docsetURL = [NSURL URLWithString:[NSString stringWithFormat:DOCSET_ARCHIVE_FORMAT, podName]];
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:docsetURL] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *xarData, NSError *connectionError) {
            if (xarData) {
                NSString *tmpFilePath = [NSString pathWithComponents:@[NSTemporaryDirectory(), [NSString stringWithFormat:@"%@.xar",podName]]];
                [xarData writeToFile:tmpFilePath atomically:YES];
                [self extractPath:tmpFilePath];
            }
        }];
    }
}

#pragma mark - NSMenuValidation Protocol Methods

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem isEqual:self.installPodsItem] || [menuItem isEqual:self.editPodfileItem]) {
        return [CocoaPodsFileManager doesPodfileExist];
    }

    return YES;
}

#pragma mark - Private

- (void)addMenuItems {
    NSMenuItem *topMenuItem = [[NSApp mainMenu] itemWithTitle:@"Product"];
    if (topMenuItem) {
        NSMenuItem *cocoaPodsMenu = [[NSMenuItem alloc] initWithTitle:@"CocoaPods" action:nil keyEquivalent:@""];
        cocoaPodsMenu.submenu = [[NSMenu alloc] initWithTitle:@"CocoaPods"];
        self.installDocsItem = [[NSMenuItem alloc] initWithTitle:@"Install Docs during Integration" action:@selector(toggleInstallDocsForPods) keyEquivalent:@""];
        self.installDocsItem.state = [self shouldInstallDocsForPods] ? NSOnState : NSOffState;
        self.installPodsItem = [[NSMenuItem alloc] initWithTitle:@"Integrate Pods" action:@selector(integratePods) keyEquivalent:@""];
        self.editPodfileItem = [[NSMenuItem alloc] initWithTitle:@"Edit Podfile" action:@selector(openPodfileForEditing) keyEquivalent:@""];
        NSMenuItem *updateCPodsItem = [[NSMenuItem alloc] initWithTitle:@"Install/Update CocoaPods" action:@selector(installCocoaPods) keyEquivalent:@""];
        [self.installDocsItem setTarget:self];
        [self.installPodsItem setTarget:self];
        [updateCPodsItem setTarget:self];
        [self.editPodfileItem setTarget:[CocoaPodsFileManager class]];
        [[cocoaPodsMenu submenu] addItem:self.installPodsItem];
        [[cocoaPodsMenu submenu] addItem:self.installDocsItem];
        [[cocoaPodsMenu submenu] addItem:[NSMenuItem separatorItem]];
        [[cocoaPodsMenu submenu] addItem:self.editPodfileItem];
        [[cocoaPodsMenu submenu] addItem:updateCPodsItem];
        [[topMenuItem submenu] insertItem:cocoaPodsMenu atIndex:[topMenuItem.submenu indexOfItemWithTitle:@"Build For"]];
    }
}

- (void)toggleInstallDocsForPods {
    [self setShouldInstallDocsForPods:![self shouldInstallDocsForPods]];
}

- (void)extractPath:(NSString *)path {
    NSArray *arguments = @[@"-xf", path, @"-C", [CocoaPods docsetInstallPath]];
    [self runShellCommand:XAR_EXECUTABLE withArgs:arguments directory:NSTemporaryDirectory() completion:nil];
}

- (void)integratePods {
    [self runShellCommand:@"/usr/bin/pod"
                 withArgs:@[@"install"]
                directory:[CocoaPodsFileManager keyWorkspaceDirectoryPath]
               completion:^(NSTask *t) {
                   if ([self shouldInstallDocsForPods]) {
                       [self installOrUpdateDocSetsForPods];
                   }
               }];
}

- (void)installCocoaPods {
    [self runShellCommand:@"/usr/bin/gem"
                 withArgs:@[@"install", @"cocoapods"]
                directory:[CocoaPodsFileManager keyWorkspaceDirectoryPath]
               completion:nil];
}

- (void)runShellCommand:(NSString *)command withArgs:(NSArray *)args directory:(NSString *)directory completion:(void(^)(NSTask *t))completion{
    __block NSMutableData *taskOutput = [NSMutableData new];
    __block NSMutableData *taskError  = [NSMutableData new];

    NSTask *task = [NSTask new];

    task.currentDirectoryPath = directory;
    task.launchPath = command;
    task.arguments  = args;

    task.standardOutput = [NSPipe pipe];
    task.standardError  = [NSPipe pipe];

    [[task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *file) {
        [taskOutput appendData:[file availableData]];
    }];

    [[task.standardError fileHandleForReading] setReadabilityHandler:^(NSFileHandle *file) {
        [taskError appendData:[file availableData]];
    }];

    [task setTerminationHandler:^(NSTask *t) {
        [t.standardOutput fileHandleForReading].readabilityHandler = nil;
        [t.standardError fileHandleForReading].readabilityHandler  = nil;
        NSString *output = [[NSString alloc] initWithData:taskOutput encoding:NSUTF8StringEncoding];
        NSString *error = [[NSString alloc] initWithData:taskError encoding:NSUTF8StringEncoding];
        NSLog(@"Shell command output: %@", output);
        NSLog(@"Shell command error: %@", error);
        if (completion) completion(t);
    }];

    @try {
        [task launch];
    }
    @catch (NSException *exception) {
        NSLog(@"Failed to launch: %@", exception);
    }
}

#pragma mark - Preferences

- (BOOL) shouldInstallDocsForPods {
    return [[NSUserDefaults standardUserDefaults] boolForKey:DMMCocoaPodsIntegrateWithDocsKey];
}

- (void) setShouldInstallDocsForPods:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:DMMCocoaPodsIntegrateWithDocsKey];
    self.installDocsItem.state = enabled ? NSOnState : NSOffState;
}

@end
