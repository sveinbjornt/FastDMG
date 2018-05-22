/*
 Copyright (c) 2012-2018, Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>
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
#import "FastDMGWindowController.h"

#define DEFAULTS [NSUserDefaults standardUserDefaults]

// Debug logging
#ifdef DEBUG
    #define DebugLog(...) NSLog(__VA_ARGS__)
#else
    #define DebugLog(...)
#endif

@interface FastDMGAppDelegate ()
{    
    BOOL hasReceivedOpenFileEvent;
    BOOL inForeground;
    BOOL numActiveTasks;
    
    FastDMGWindowController *windowController;
}

- (IBAction)openFiles:(id)sender;

@end

@implementation FastDMGAppDelegate

+ (void)initialize {
    NSDictionary *defaults = @{ @"InBackground": @(YES),
                                @"OpenDiskImage": @(YES),
                                @"QuitAfterMounting": @(YES) };
    [DEFAULTS registerDefaults:defaults];
}

- (void)awakeFromNib {
    if (!inForeground && [DEFAULTS boolForKey:@"RunInBackground"] == NO) {
        inForeground = [self transformToForeground];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(taskDone:)
                                                 name:@"FastDMGTaskDoneNotification"
                                               object:nil];
}

#pragma mark -

- (BOOL)transformToForeground {
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    
    OSStatus ret = TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    if (ret != noErr) {
        DebugLog(@"Failed to transform application to foreground state: %d", ret);
        return NO;
    }
    
    return YES;
}

- (IBAction)showWindow:(id)sender {
    // Load window lazily
    if (windowController == nil) {
        windowController = [[FastDMGWindowController alloc] initWithWindowNibName:@"FastDMGWindow"];
    }
    [windowController showWindow:self];
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // We only become a foreground application if the
    // application wasn't launched via opening a file.
    // In that case, we show FastDMG Settings window
    if (hasReceivedOpenFileEvent == NO) {
        if (!inForeground) {
            inForeground = [self transformToForeground];
        }
        
        [self showWindow:self];
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    }
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filePath {
    hasReceivedOpenFileEvent = YES;
    
    [self mountDiskImage:filePath];
    
    return YES;
}

#pragma mark - Handle disk images

- (IBAction)openFiles:(id)sender {
    // Create open panel
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    //[oPanel setAllowedFileTypes:@"dmg", @"com.apple.disk-image"];

    // Run it modally
    if ([oPanel runModal] == NSFileHandlingPanelOKButton) {
        for (NSURL *url in [oPanel URLs]) {
            [self mountDiskImage:[url path]];
        }
    }
}

- (void)mountDiskImage:(NSString *)diskImagePath {
    
    numActiveTasks += 1;
    
    // Set task off in high priority background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{ @autoreleasepool {
        DebugLog(@"Launching task: %@", diskImagePath);
        
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/hdiutil"; // present on all macOS systems
        
        NSMutableArray *args = [@[@"attach",
                                  diskImagePath,
                                  @"-plist",
                                  @"-noautoopen",
                                  @"-noautofsck",
                                  @"-ignorebadchecksums",
                                  @"-noidme"]
                                mutableCopy];
        
//        if ([DEFAULTS boolForKey:@"OpenDiskImage"]) {
//            [args addObject:@"-autoopen"];
//        }
        
        task.arguments = args;
        
        // STDIN
        task.standardInput = [NSPipe pipe];
        NSFileHandle *inputHandle = [task.standardInput fileHandleForWriting];
        // Auto-accept EULAs by feeding 'Y' into STDIN
        [inputHandle writeData:[@"Y\n" dataUsingEncoding:NSUTF8StringEncoding]];

        // STDOUT
        // We're only interested in output if we need
        // to show image contents in the Finder
        if ([DEFAULTS boolForKey:@"OpenDiskImage"]) {
            task.standardOutput = [NSPipe pipe];
        } else {
            task.standardOutput = [NSFileHandle fileHandleWithNullDevice];
        }
        
        // STDERR
        task.standardError = [NSFileHandle fileHandleWithNullDevice];
        
        // Launch
        [task launch];
        [inputHandle closeFile]; // Close STDIN
        [task waitUntilExit];
        
        DebugLog(@"Task termination status: %d", task.terminationStatus);
        
        // Open disk image in Finder
        if (task.terminationStatus == 0 && [DEFAULTS boolForKey:@"OpenDiskImage"]) {
        
            // Parse task output
            NSString *mountPoint = [self parseOutputForMountPath:[[task.standardOutput fileHandleForReading] readDataToEndOfFile]];
            
            if (mountPoint) {
                // Make sure volume has been mounted at mount point
                int polling_ms = 50000; // 0.05 sec
                int max = 1000000/polling_ms; // Give it a second to mount
                int cnt = 0;
                while(cnt < max && [[NSFileManager defaultManager] fileExistsAtPath:mountPoint] == NO) {
                    usleep(polling_ms);
                    cnt++;
                    DebugLog(@"Sleeping, no file at %@", mountPoint);
                }
                
                if (cnt == max-1) {
                    DebugLog(@"Mount point '%@' doesn't exist", mountPoint);
                } else {
                    // Show in Finder
                    DebugLog(@"Revealing '%@' in Finder", mountPoint);
                    [[NSWorkspace sharedWorkspace] openFile:mountPoint withApplication:@"Finder" andDeactivate:YES];
                }
            } else {
                // NSBeep();
            }
        }
        
        // Notify on main thread that task is done
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (task.terminationStatus != 0) {
                [self handleFailure:diskImagePath];
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FastDMGTaskDoneNotification" object:diskImagePath];
            
            DebugLog(@"Finished processing %@", diskImagePath);
        });
        
    }});
}

- (NSString *)parseOutputForMountPath:(NSData *)outputData {
    
    NSString *outputStr = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    DebugLog(@"Output:\n%@", outputStr);
    
    // Search for property list output
    NSString *xmlHeader = @"<?xml ";
    if ([outputStr hasPrefix:xmlHeader] == NO) {
        NSArray *components = [outputStr componentsSeparatedByString:xmlHeader];
        NSString *plistString = [NSString stringWithFormat:@"%@%@", xmlHeader, [components lastObject]];
        outputData = [plistString dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    NSError *error = nil;
    NSPropertyListFormat format;
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:outputData
                                                                    options:NSPropertyListImmutable
                                                                     format:&format
                                                                      error:&error];
    
    if (plist == nil) {
        DebugLog(@"Could not parse output as plist: %@", [error localizedDescription]);
        return nil;
    }
    
    // Search plist for mount point
    for (NSDictionary *dict in plist[@"system-entities"]) {
        if (dict[@"mount-point"]) {
            return dict[@"mount-point"];
        }
    }

    return nil;
}

- (void)taskDone:(id)obj {
    numActiveTasks -= 1;
    if (numActiveTasks == 0 && windowController == nil && [DEFAULTS boolForKey:@"QuitAfterMounting"]) {
        [[NSApplication sharedApplication] terminate:self];
    }
}

- (void)handleFailure:(NSString *)filePath {
    NSBeep();
    [NSApp activateIgnoringOtherApps:YES];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Try DiskImageMounter"];
    [alert addButtonWithTitle:@"Abort"];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:@"Unable to mount disk image"];
    
    NSString *msg = [NSString stringWithFormat:@"FastDMG failed to mount \
the disk image “%@”. Would you like to try using Apple's DiskImageMounter?", [filePath lastPathComponent]];
    [alert setInformativeText:msg];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        DebugLog(@"Opening '%@' with DiskImageMounter", filePath);
        [[NSWorkspace sharedWorkspace] openFile:filePath withApplication:@"DiskImageMounter"];
    }
}

@end
