/*

File: MainController.m

Abstract: Top-Level Controller Class for CocoaSlides

Version: 1.4

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Computer, Inc. ("Apple") in consideration of your agreement to the
following terms, and your use, installation, modification or
redistribution of this Apple software constitutes acceptance of these
terms.  If you do not agree with these terms, please do not use,
install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software. 
Neither the name, trademarks, service marks or logos of Apple Computer,
Inc. may be used to endorse or promote products derived from the Apple
Software without specific prior written permission from Apple.  Except
as expressly stated in this notice, no other rights or licenses, express
or implied, are granted by Apple herein, including but not limited to
any patent rights that may be infringed by your derivative works or by
other works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright � 2006 Apple Computer, Inc., All Rights Reserved

*/

#import "MainController.h"
#import "BrowserWindowController.h"

@implementation MainController

- (void)openBrowserWindow:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:NO];
    int result = [openPanel runModalForDirectory:[@"~/Pictures" stringByExpandingTildeInPath] file:nil types:nil];
    if (result == NSOKButton) {
        [self openBrowserWindowForPath:[[openPanel filenames] objectAtIndex:0]];
    }
}

- (BOOL)openBrowserWindowForPath:(NSString *)path {
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    if (exists && isDirectory) {
        BrowserWindowController *browserWindowController = [[BrowserWindowController alloc] initWithPath:path];
        if (browserWindowController) {
            [browserWindowController showWindow:self];
            return YES;
        }
    } else {
        [[NSAlert alertWithMessageText:@"Can't browse path" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:(exists ? @"Path exists but isn't a directory (%@)" : @"Path doesn't exist (%@)"), path] runModal];
    }
    return NO;
}

- (void)browseNatureDesktopPictures:(id)sender {
   // [self openBrowserWindowForPath:@"/Library/Desktop Pictures/Nature/"];
    [self openBrowserWindowForPath:@"/Library/Desktop Pictures/"];
}

- (void)browsePlantsDesktopPictures:(id)sender {
    //[self openBrowserWindowForPath:@"/Library/Desktop Pictures/Plants/"];
    [self openBrowserWindowForPath:@"/Library/Desktop Pictures/"];
}

- (void)browseBeachScreenSaverPictures:(id)sender {
    [self openBrowserWindowForPath:@"/System/Library/Screen Savers/Beach.slideSaver/Contents/Resources/"];
}

- (void)browseCosmosScreenSaverPictures:(id)sender {
    [self openBrowserWindowForPath:@"/System/Library/Screen Savers/Cosmos.slideSaver/Contents/Resources/"];
}

- (void)browseForestScreenSaverPictures:(id)sender {
    [self openBrowserWindowForPath:@"/System/Library/Screen Savers/Forest.slideSaver/Contents/Resources/"];
}

- (void)browseNaturePatternsScreenSaverPictures:(id)sender {
    [self openBrowserWindowForPath:@"/System/Library/Screen Savers/Nature Patterns.slideSaver/Contents/Resources/"];
}

- (void)browsePaperShadowScreenSaverPictures:(id)sender {
    [self openBrowserWindowForPath:@"/System/Library/Screen Savers/Paper Shadow.slideSaver/Contents/Resources/"];
}

@end

@implementation MainController (NSApplicationDelegateMethods)

// Suppress default behavior of opening an "Untitled" browser on launch.
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
    return NO;
}

// Auto-open a browser on launch.
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Try default path for WWDC demo first.
    NSString *path = [@"~/Pictures/All Desktop Pictures" stringByExpandingTildeInPath];
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
    if (exists && isDirectory) {
        [self openBrowserWindowForPath:path];
    } else {
        [self browseNatureDesktopPictures:self];
    }
}

@end
