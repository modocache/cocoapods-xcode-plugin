//
//  CocoaPodsSpec.m
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

#import <Kiwi/Kiwi.h>
#import "CocoaPods.h"
#import "CocoaPodsFileManager.h"


static NSString * const kCocoaPodsPluginPath =
    @"Library/Application Support/Developer/Shared/Xcode/Plug-ins/CocoaPods.xcplugin";


NSMenu *createFakeMenu() {
    NSMenuItem *productMenuItem = [[NSMenuItem alloc] initWithTitle:@"Product"
                                                             action:nil
                                                      keyEquivalent:@""];
    productMenuItem.submenu = [[NSMenu alloc] initWithTitle:@"ProductSubmenu"];
    [productMenuItem.submenu addItemWithTitle:@"Build For" action:nil keyEquivalent:@""];

    NSMenu *fakeMenu = [[NSMenu alloc] initWithTitle:@"CocoaPodsTests"];
    [fakeMenu addItem:productMenuItem];
    return fakeMenu;
}


@interface CocoaPods (TestExtensions)
+ (void)pluginDidLoad:(NSBundle *)bundle;
@end


SPEC_BEGIN(CocoaPodsSpec)

describe(@"CocoaPods", ^{
    describe(@"+docsetInstallPath", ^{
        it(@"returns the docset path appended to the user's home directory", ^{
            [NSString stub:@selector(pathWithComponents:)
                 andReturn:@"Penny Lane"
             withArguments:[KWAny any], @"/Library/Developer/Shared/Documentation/DocSets/"];

            [[[CocoaPods docsetInstallPath] should]
                equal:@"Penny Lane"];
        });
    });

    describe(@"+pluginDidLoad:", ^{
        __block NSBundle *pluginBundle = nil;
        __block CocoaPods *cocoaPods = nil;

        beforeEach(^{
            [NSApp stub:@selector(mainMenu) andReturn:createFakeMenu()];

            NSString *pluginPath = [NSString pathWithComponents:@[NSHomeDirectory(), kCocoaPodsPluginPath]];
            pluginBundle = [NSBundle bundleWithPath:pluginPath];

            NSError *pluginLoadError = nil;
            [pluginBundle loadAndReturnError:&pluginLoadError];
            [pluginBundle.principalClass performSelector:@selector(pluginDidLoad:)
                                              withObject:pluginBundle];

            if (pluginLoadError) {
                [NSException raise:NSInternalInconsistencyException
                            format:@"Could not load CocoaPods plugin in order to run the test suite."];
            }

            cocoaPods = [[pluginBundle principalClass] new];
        });

        describe(@"'Product' menu", ^{
            __block NSMenuItem *productMenuItem = nil;
            beforeEach(^{
                productMenuItem = [[NSApp mainMenu] itemWithTitle:@"Product"];
            });

            it(@"has the menu item 'Product > CocoaPods'", ^{
                [[[productMenuItem.submenu itemWithTitle:@"CocoaPods"] shouldNot] beNil];
            });

            it(@"'Product > CocoaPods' is above 'Product > Build For'", ^{
                [[theValue([productMenuItem.submenu indexOfItemWithTitle:@"CocoaPods"]) should]
                    equal:theValue([productMenuItem.submenu indexOfItemWithTitle:@"Build For"] - 1)];
            });

            describe(@"'Product > CocoaPods' submenu", ^{
                __block NSMenuItem *cocoaPodsMenuItem = nil;
                beforeEach(^{
                    cocoaPodsMenuItem = [productMenuItem.submenu itemWithTitle:@"CocoaPods"];
                });

                it(@"has the menu item 'Product > CocoaPods > Integrate Pods'", ^{
                    [[[cocoaPodsMenuItem.submenu itemWithTitle:@"Integrate Pods"] shouldNot] beNil];
                });

                describe(@"'Product > CocoaPods > Integrate Pods' menu item", ^{
                    __block NSMenuItem *integratePodsMenuItem = nil;
                    beforeEach(^{
                        integratePodsMenuItem =
                            [cocoaPodsMenuItem.submenu itemWithTitle:@"Integrate Pods"];
                    });

                    context(@"a Podfile does not exist in the workspace directory", ^{
                        beforeEach(^{
                            [CocoaPodsFileManager stub:@selector(doesPodfileExist) andReturn:theValue(NO)];
                        });

                        it(@"is disabled", ^{
                            [[theValue([cocoaPods validateMenuItem:integratePodsMenuItem]) should] beNo];
                        });
                    });

                    context(@"a Podfile does exist in the workspace directory", ^{
                        beforeEach(^{
                            [CocoaPodsFileManager stub:@selector(doesPodfileExist) andReturn:theValue(YES)];
                        });

                        it(@"is enabled", ^{
                            [[theValue([cocoaPods validateMenuItem:integratePodsMenuItem]) should] beYes];
                        });
                    });
                });
            });
        });
    });
});

SPEC_END
