//
//  CocoaPodsFileManagerSpec.m
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

#import "Kiwi.h"
#import "CocoaPodsFileManager.h"

SPEC_BEGIN(CocoaPodsFileManagerSpec)

describe(@"CocoaPodsFileManager", ^{
    describe(@"+podfilePath", ^{
        it(@"appends 'Podfile' to the workspace path", ^{
            [CocoaPodsFileManager stub:@selector(keyWorkspaceDirectoryPath)
                             andReturn:@"While My Guitar Gently Weeps"];

            [[[CocoaPodsFileManager podfilePath] should]
                equal:@"While My Guitar Gently Weeps/Podfile"];
        });
    });

    describe(@"+doesPodfileExist", ^{
        it(@"queries the filesystem to determine if the Podfile exists", ^{
            [CocoaPodsFileManager stub:@selector(podfilePath) andReturn:@"Abbey Road"];
            [[NSFileManager defaultManager] stub:@selector(fileExistsAtPath:)
                                       andReturn:theValue(YES)
                                   withArguments:@"Abbey Road"];

            [[theValue([CocoaPodsFileManager doesPodfileExist]) should] beYes];
        });
    });

    describe(@"+openPodfileForEditing", ^{
        beforeEach(^{
            [CocoaPodsFileManager stub:@selector(podfilePath) andReturn:@"It's Only Love"];
            [[NSFileManager defaultManager] stub:@selector(createFileAtPath:contents:attributes:)];
        });

        context(@"the Podfile does not already exist", ^{
            beforeEach(^{
                [CocoaPodsFileManager stub:@selector(doesPodfileExist) andReturn:theValue(NO)];
            });

            it(@"creates the Podfile", ^{
                [[[NSFileManager defaultManager] should] receive:@selector(createFileAtPath:contents:attributes:)
                                                   withArguments:@"It's Only Love", [KWAny any], [KWAny any]];
                [CocoaPodsFileManager openPodfileForEditing];
            });
        });

        it(@"opens the Podfile in Xcode", ^{
            KWMock <NSApplicationDelegate> *mockXcodeDelegate =
            [KWMock mockForProtocol:@protocol(NSApplicationDelegate)];
            NSApplication *mockXcode = [NSApplication mock];
            [mockXcode stub:@selector(delegate) andReturn:mockXcodeDelegate];

            [NSApplication stub:@selector(sharedApplication) andReturn:mockXcode];

            [[mockXcodeDelegate should] receive:@selector(application:openFile:)
                                  withArguments:mockXcode, @"It's Only Love"];
            [CocoaPodsFileManager openPodfileForEditing];
        });
    });
});

SPEC_END

