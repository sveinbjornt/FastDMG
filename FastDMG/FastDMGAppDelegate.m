/*
 Copyright (c) 2012-2025, Sveinbjorn Thordarson <sveinbjorn@sveinbjorn.org>
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

#ifdef DEBUG
    #define DLog(...) NSLog(__VA_ARGS__)
#else
    #define DLog(...)
#endif

@interface FastDMGAppDelegate ()
{    
    BOOL hasReceivedOpenFileEvent;
    BOOL inForeground;
    BOOL numActiveTasks;
    
    FastDMGWindowController *windowController;
}
@end

@implementation FastDMGAppDelegate

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [DEFAULTS registerDefaults:[FastDMGAppDelegate defaults]];
    });
}

+ (NSDictionary *)defaults {
    return @{ @"RunInBackground": @(YES),
              @"OpenDiskImage": @(YES),
              @"QuitAfterMounting": @(YES) };
}

- (void)awakeFromNib {
    // Transition to foreground if RunInBackground setting is NO
    if (!inForeground && [DEFAULTS boolForKey:@"RunInBackground"] == NO) {
        inForeground = [self transformToForeground];
    }
    // Start listening for task done notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(taskDone:)
                                                 name:@"FastDMGTaskDoneNotification"
                                               object:nil];
}

#pragma mark -

- (BOOL)transformToForeground {
    // Use nasty Carbon API to transition between application states
    ProcessSerialNumber psn = { 0, kCurrentProcess };
    OSStatus ret = TransformProcessType(&psn, kProcessTransformToForegroundApplication);
    if (ret != noErr) {
        DLog(@"Failed to transform application to foreground state: %d", ret);
        return NO;
    }
    
    return YES;
}

- (IBAction)showWindow:(id)sender {
    // Load window lazily
    if (windowController == nil) {
        windowController = [[FastDMGWindowController alloc] initWithWindowNibName:@"MainWindow"];
    }
    [windowController showWindow:self];
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // We only become a foreground application if the
    // application wasn't launched by opening a file.
    // In that case, we show FastDMG Settings window.
    [self performSelector:@selector(showPrefs) withObject:nil afterDelay:0.5];
}

- (BOOL)application:(NSApplication *)app openFile:(NSString *)path {
    hasReceivedOpenFileEvent = YES;
    
    [self mountDiskImage:path];
    
    return YES;
}

- (void)showPrefs {
    // Show Preferences window
    if (hasReceivedOpenFileEvent == NO) {
        if (!inForeground) {
            inForeground = [self transformToForeground];
        }
        
        [self showWindow:self];
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    }
}

#pragma mark - Handle disk images

- (IBAction)openFiles:(id)sender {
    // Create open panel
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    
    // Run it modally
    if ([oPanel runModal] == NSModalResponseOK) {
        for (NSURL *url in [oPanel URLs]) {
            [self mountDiskImage:[url path]];
        }
    }
}

- (void)mountDiskImage:(NSString *)diskImagePath {
    
    numActiveTasks += 1;
    
    // Set task off in high priority background thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{ @autoreleasepool {
        DLog(@"Launching task: %@", diskImagePath);
        
        NSTask *task = [NSTask new];
        task.launchPath = @"/usr/bin/hdiutil"; // present on all macOS systems
        
        // See man hdiutil for details
        task.arguments = @[@"attach",
                           diskImagePath,
                           @"-plist",
                           @"-noautoopen",
                           @"-noautofsck",
                           @"-noverify",
                           @"-ignorebadchecksums",
                           @"-noidme"];
        
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
        
        DLog(@"Task termination status: %d", task.terminationStatus);
        
        // Open disk image in Finder
        if (task.terminationStatus == 0 && [DEFAULTS boolForKey:@"OpenDiskImage"]) {
        
            // Parse task output
            NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
            NSString *mountPoint = [self parseOutputForMountPath:data];
            
            if (mountPoint) {
                // Make sure volume has been mounted at mount point
                int polling_ms = 50000; // 0.05 sec
                int max = 1000000/polling_ms;
                int cnt = 0;
                // Give it max 1 sec to mount
                while (cnt < max && [[NSFileManager defaultManager] fileExistsAtPath:mountPoint] == NO) {
                    usleep(polling_ms);
                    cnt++;
                    DLog(@"Sleeping, no file at %@", mountPoint);
                }
                
                if (cnt == max-1) {
                    DLog(@"Mount point '%@' doesn't exist", mountPoint);
                } else {
                    // Show in Finder
                    DLog(@"Revealing '%@' in Finder", mountPoint);
                    [[NSWorkspace sharedWorkspace] openFile:mountPoint 
                                            withApplication:@"Finder"
                                              andDeactivate:YES];
                }
            }
        }
        
        // Notify on main thread that task is done
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (task.terminationStatus != 0) {
                [self handleFailure:diskImagePath];
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"FastDMGTaskDoneNotification" object:diskImagePath];
            
            DLog(@"Finished processing %@", diskImagePath);
        });
        
    }});
}

- (NSString *)parseOutputForMountPath:(NSData *)outputData {
    // Create string object
    NSString *outputStr = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    if (outputStr) {
        DLog(@"Output:\n%@", outputStr);
    } else {
        DLog(@"Unable to read output data as UTF8 string");
        return nil;
    }
    
    // Search for property list output
    NSString *xmlHeader = @"<?xml ";
    if ([outputStr hasPrefix:xmlHeader] == NO) {
        NSArray *components = [outputStr componentsSeparatedByString:xmlHeader];
        NSString *plistString = [NSString stringWithFormat:@"%@%@", xmlHeader, [components lastObject]];
        outputData = [plistString dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    // Parse property list
    NSError *error = nil;
    NSPropertyListFormat format;
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:outputData
                                                                    options:NSPropertyListImmutable
                                                                     format:&format
                                                                      error:&error];
    if (plist == nil) {
        DLog(@"Could not parse output string as plist: %@", [error localizedDescription]);
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
    // Quit if no tasks and QuitAfterMounting is true
    if (numActiveTasks == 0 && windowController == nil && [DEFAULTS boolForKey:@"QuitAfterMounting"]) {
        [[NSApplication sharedApplication] terminate:self];
    }
}

- (void)handleFailure:(NSString *)filePath {
    NSBeep();
    [NSApp activateIgnoringOtherApps:YES];
    
    // Show alert asking whether to try with DiskImageMounter
    NSAlert *alert = [NSAlert new];
    [alert addButtonWithTitle:@"Try DiskImageMounter"];
    [alert addButtonWithTitle:@"Abort"];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert setMessageText:@"Unable to mount disk image"];
    
    NSString *msg = [NSString stringWithFormat:@"FastDMG failed to mount \
the disk image “%@”. Would you like to try using Apple's DiskImageMounter?", [filePath lastPathComponent]];
    [alert setInformativeText:msg];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        DLog(@"Opening '%@' with DiskImageMounter", filePath);
        [[NSWorkspace sharedWorkspace] openFile:filePath withApplication:@"DiskImageMounter"];
    }
}

@end
