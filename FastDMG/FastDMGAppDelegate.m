/*
 Copyright (c) 2018, Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this
 list of conditions and the following disclaimer in the documentation and/or other
 materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may
 be used to endorse or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
*/

#import "FastDMGAppDelegate.h"
#import <Carbon/Carbon.h>

#define DEFAULTS [NSUserDefaults standardUserDefaults]

@interface FastDMGAppDelegate ()
{
    IBOutlet NSWindow *prefsWindow;
    BOOL hasOpenedFile;
    BOOL inForeground;
}
@end

@implementation FastDMGAppDelegate

+ (void)initialize {
    NSString *defaultsPath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
    NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPath];
    [DEFAULTS registerDefaults:defaults];
}

- (void)awakeFromNib {
    NSLog(@"Awake from nib");
    if ([DEFAULTS boolForKey:@"RunInBackground"] == NO) {
        inForeground = [self transformToForeground];
    }
}

- (BOOL)transformToForeground {
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    OSStatus ret = TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    if (ret != noErr) {
        NSLog(@"Failed to transform application to foreground state");
        return NO;
    }
    
    return YES;
}

- (void)activate {
//    ProcessSerialNumber psn = { 0, kCurrentProcess };
//    SetFrontProcess(&psn);
    [NSApp activateIgnoringOtherApps:YES];
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // We only become a foreground application if the
    // application wasn't launched via opening a file
    if (hasOpenedFile == NO) {
        if (!inForeground) {
            [self transformToForeground];
        }
        [self activate];
        [prefsWindow makeKeyAndOrderFront:self];
    } else {
        [[NSApplication sharedApplication] terminate:self];
    }
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    hasOpenedFile = YES;

//    // Make sure it's a dmg
//    if ([self isDMG:filename] == NO) {
//        NSBeep();
//        return NO;
//    }
    
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:filename]];
    
    if ([self attachDiskImage:filename] == NO) {
        NSBeep();
        return NO;
    };
    
    return YES;
}

#pragma mark -

- (BOOL)attachDiskImage:(NSString *)dmgPath {

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/hdiutil"; // present on all macOS systems

    NSMutableArray *args = [@[@"attach", dmgPath, @"-plist"] mutableCopy];
    if ([DEFAULTS boolForKey:@"OpenDiskImage"]) {
        [args addObject:@"-autoopen"];
    }
    if ([DEFAULTS boolForKey:@"VerifyDiskImage"] == NO) {
        [args addObject:@"-noverify"];
    }
    task.arguments = args;
    
    // STDIN
    NSPipe *inputPipe = [NSPipe pipe];
    NSFileHandle *inputHandle = [inputPipe fileHandleForWriting];
    task.standardInput = inputPipe;
    
    // STDOUT
    NSPipe *outputPipe = [NSPipe pipe];
    task.standardOutput = outputPipe;
    NSFileHandle *outputHandle = [outputPipe fileHandleForReading];
    
    // STDERR
    task.standardError = [NSFileHandle fileHandleWithNullDevice];
    
    // Auto-accept EULAs by feeding 'Y' into STDIN
    [inputHandle writeData:[@"Y\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Launch
    [task launch];
    [inputHandle closeFile];
    [task waitUntilExit];
    
    NSData *outputData = [outputHandle readDataToEndOfFile];
//    NSString *outputStr = [[NSString alloc] initWithData:outputData
//                                                encoding:NSUTF8StringEncoding];
//    NSLog(@"Output: %@", outputStr);
//
//    NSString *error;
//    NSPropertyListFormat format;
//    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:outputData
//                                                                    options:NSPropertyListImmutable
//                                                                     format:&format
//                                                                      error:&error];
//
//    if (!plist) {
//        NSLog(@"Error: %@",error);
//        return NO;
//    }
//    NSLog(@"Termination status: %d", task.terminationStatus);
    return (task.terminationStatus == 0);
}

- (BOOL)isDMG:(NSString *)filePath {
    // Check suffix
    if ([filePath hasSuffix:@".dmg"]) {
        return YES;
    }

    // Check UTI
    NSString *fileType = [[NSWorkspace sharedWorkspace] typeOfFile:filePath error:nil];
    if ([[NSWorkspace sharedWorkspace] type:fileType conformsToType:@"com.apple.disk-image"]) {
        return YES;
    }
    
    // There is no single DMG file format. DMGs come in a variety of sub-formats, corresponding
    // to the different tools which create them, and their compression schemes. The common
    // denominator of most of these is the existence of a 512-byte trailer at the end of the file.
    // This trailer is identifiable by a magic 32-bit value, 0x6B6F6C79, which is "koly" in ASCII.
    NSError *error;
    NSData *data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:filePath]
                                         options:NSDataReadingMappedAlways
                                           error:&error];
    if ([data length] < 512) {
        return NO;
    }
    
    // Read last 512 bytes
    NSUInteger length = [data length];
    
    NSData *trailerData = [data subdataWithRange:NSMakeRange(length-512, 4)];
    char magic[] = { 'k', 'o', 'l', 'y' };
    NSData *dmgTrailerData = [NSData dataWithBytes:&magic length:4];
    
    return [trailerData isEqualToData:dmgTrailerData];
}

@end
