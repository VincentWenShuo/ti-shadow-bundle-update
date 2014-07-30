/**
 * Your Copyright Here
 *
 * Appcelerator Titanium is Copyright (c) 2009-2010 by Appcelerator, Inc.
 * and licensed under the Apache Public License (version 2)
 */
#import "MaCarTishadowBundleUpdateModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"

@implementation MaCarTishadowBundleUpdateModule

#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID
{
	return @"e80f36f5-f659-41c1-8340-39fddac79ed7";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
	return @"ma.car.tishadow.bundle.update";
}

#pragma mark Lifecycle

-(void)startup
{
	// this method is called when the module is first loaded
	// you *must* call the superclass
	[super startup];
	
	NSLog(@"[INFO] %@ loaded",self);
    self->queue = [NSOperationQueue new];
}

-(void)shutdown:(id)sender
{
	// this method is called when the module is being unloaded
	// typically this is during shutdown. make sure you don't do too
	// much processing here or the app will be quit forceably
	
	// you *must* call the superclass
	[super shutdown:sender];
}

#pragma mark Cleanup 

-(void)dealloc
{
	// release any resources that have been retained by the module
    [self->queue release];
    
	[super dealloc];
}

#pragma mark Internal Memory Management

-(void)didReceiveMemoryWarning:(NSNotification*)notification
{
	// optionally release any resources that can be dynamically
	// reloaded once memory is available - such as caches
	[super didReceiveMemoryWarning:notification];
}

#pragma mark Listener Notifications

-(void)_listenerAdded:(NSString *)type count:(int)count
{
	if (count == 1 && [type isEqualToString:@"my_event"])
	{
		// the first (of potentially many) listener is being added 
		// for event named 'my_event'
	}
}

-(void)_listenerRemoved:(NSString *)type count:(int)count
{
	if (count == 0 && [type isEqualToString:@"my_event"])
	{
		// the last listener called for event named 'my_event' has
		// been removed, we can optionally clean up any resources
		// since no body is listening at this point for that event
	}
}

#pragma Public APIs

-(id)example:(id)args
{
	// example method
	return @"hello world";
}

-(id)exampleProp
{
	// example property getter
	return @"hello world";
}

-(void)setExampleProp:(id)value
{
	// example property setter
}

-(id)send:(id)args
{
    NSLog(@"[INFO] tishadow bundle update send!");
    
    NSInvocationOperation *operation = [[NSInvocationOperation alloc]
                                        initWithTarget:self
                                        selector:@selector(startDownloading:)
                                        object:args];
    [self->queue addOperation:operation];
    [operation release];
    
    return @"";
}

-(void)startDownloading:(id)args
{
    NSLog(@"[INFO] tishadow bundle update startDownloading!");
    [self->queue setSuspended:YES];
    
    NSUserDefaults *defaultsObject = [[NSUserDefaults standardUserDefaults] retain];
    //KrollCallback* tcallback = [[args objectAtIndex:0] valueForKey:@"onStateChanged"];
    self->m_callback = (KrollCallback*)[[args objectAtIndex:0] valueForKey:@"onStateChanged"];
    // Send a synchronous request
    NSString* downlaodUrl = [[args objectAtIndex:0] valueForKey:@"bundle_download_url"];
    NSString* unzipdUrl = [[args objectAtIndex:0] valueForKey:@"bundle_decompress_dir"];
    NSString* backUpUrl = [[args objectAtIndex:0] valueForKey:@"standby_dir"];
    NSString* lastestVersion = [[args objectAtIndex:0] valueForKey:@"latest_bundle_version"];
    if( [defaultsObject stringForKey:@"updateVersion"] != nil && [lastestVersion longLongValue] <= [[defaultsObject stringForKey:@"updateVersion"] longLongValue] ){
        NSLog(@"[INFO] tishadow bundle is alreday downloaded!");
        [self doCallback:@"INTERRUPTED"];
        return;
    }
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    basePath = [basePath stringByAppendingString:@"/"];
    NSString *destinationPath = [basePath stringByAppendingString:backUpUrl];
    NSString* currentDownload = [destinationPath stringByAppendingString:@".zip"];
    NSLog(currentDownload);
    
    NSURLRequest * urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:downlaodUrl]];
    NSURLResponse * response = nil;
    NSError * error = nil;
    NSData * data = [NSURLConnection sendSynchronousRequest:urlRequest
                                          returningResponse:&response
                                                      error:&error];
    // Parse data here
    if (error == nil)
    {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if( [defaultsObject stringForKey:@"updateVersion"] != nil && [lastestVersion longLongValue] <= [[defaultsObject stringForKey:@"updateVersion"] longLongValue] ){
            NSLog(@"[INFO] tishadow bundle is alreday downloaded!");
            [fileManager removeItemAtPath:currentDownload error:&error];
            [self doCallback:@"INTERRUPTED"];
            return;
        }
        
        // Attempt to open the file and write the downloaded data to it
        if (![fileManager fileExistsAtPath:currentDownload]) {
            [fileManager createFileAtPath:currentDownload contents:nil attributes:nil];
        }
        else{
            BOOL success = [fileManager removeItemAtPath:currentDownload error:&error];
            if (success) {
                [fileManager createFileAtPath:currentDownload contents:nil attributes:nil];
            }
            else{
                NSLog(@"Could not delete download file -:%@ ",[error localizedDescription]);
            }
        }
        // Append data to end of file
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:currentDownload];
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:data];
        [fileHandle closeFile];
        
        // Unzipping
        [SSZipArchive unzipFileAtPath:currentDownload toDestination:destinationPath];
        BOOL success = [fileManager removeItemAtPath:currentDownload error:&error];
        if (!success) {
            NSLog(@"Could not delete download file -:%@ ",[error localizedDescription]);
        }
        //[self prepareUpdate:args];
        [defaultsObject setBool:YES forKey:@"updateReady"];
        [defaultsObject setValue:lastestVersion forKey:@"updateVersion"];
        [defaultsObject synchronize];
        
        NSString* manifestFile = [destinationPath stringByAppendingString:@"/manifest.mf"];
        BOOL forceUpdate = [self isForceUpdate:manifestFile];
        if(self->m_callback){
            NSDictionary* dict = [[[NSDictionary alloc] initWithObjectsAndKeys:@"READY_FOR_APPLY", @"state", [NSNumber numberWithBool:forceUpdate], @"forceUpdate", nil] autorelease];
            NSArray* array = [NSArray arrayWithObjects: dict, nil];
            [self->m_callback call:array thisObject:self];
        }
    }
    else{
        [self doCallback:@"INTERRUPTED"];
    }
    [self->queue setSuspended:NO];
}

-(BOOL)isForceUpdate:(NSString*)manifDir
{
    NSLog(manifDir);
    NSError * error = nil;
    NSString *myData= [NSString stringWithContentsOfFile:manifDir encoding:NSUTF8StringEncoding error:&error];
    if (error == nil && myData){
        NSArray *lines = [myData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        if(lines){
            NSString* forceUpdate = [lines objectAtIndex:1];
            if(forceUpdate){
                NSArray *update = [forceUpdate componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":"]];
                if(update){
                    if ( [[update objectAtIndex:1] isEqualToString:@"undefined"] ){
                        return FALSE;
                    }
                    else{
                        return TRUE;
                    }
                }
            }
        }
    }
    else{
        return FALSE;
    }
}

 
-(void)prepareUpdate:(id)args
{
    NSLog(@"[INFO] tishadow bundle update prepareUpdate!");
    NSString* unzipdUrl = [[args objectAtIndex:0] valueForKey:@"bundle_decompress_dir"];
    NSString* backUpUrl = [[args objectAtIndex:0] valueForKey:@"standby_dir"];
    NSString* sourceUrl = [[args objectAtIndex:0] valueForKey:@"app_name"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    basePath = [basePath stringByAppendingString:@"/"];
    NSString *downloadDir = [basePath stringByAppendingString:unzipdUrl];
    NSLog(downloadDir);
    NSString *backUpDir = [basePath stringByAppendingString:backUpUrl];
    NSLog(backUpDir);
    NSString *sourceDir = [basePath stringByAppendingString:sourceUrl];
    NSLog(sourceDir);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError * error = nil;

    BOOL isDir;
    if([fileManager fileExistsAtPath:backUpDir isDirectory:&isDir] && isDir){
        NSLog(@"Back up directory exit!");
        if(![fileManager removeItemAtPath:backUpDir error:&error]){
            NSLog(@"Error deleting files: %@", [error localizedDescription]);
        }
    }
    if([fileManager fileExistsAtPath:sourceDir isDirectory:&isDir] && isDir){
        NSLog(@"Start copying");
        if (![fileManager copyItemAtPath:sourceDir toPath:backUpDir error:&error]) {
            NSLog(@"Error copying files: %@", [error localizedDescription]);
        }
    }

}

-(id)applyUpdateOnline:(id)args
{
    return [self doApplyUpdateOnline:args];
}

-(id)doApplyUpdateOnline:(id)args
{
	NSLog(@"[INFO] tishadow bundle update applyUpdateOnline!");
    
    self->m_callback = [[args objectAtIndex:0] valueForKey:@"onStateChanged"];
    NSString* backUpUrl = [[args objectAtIndex:0] valueForKey:@"standby_dir"];
    NSString* sourceUrl = [[args objectAtIndex:0] valueForKey:@"app_name"];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    basePath = [basePath stringByAppendingString:@"/"];
    NSString *carmaDir = [basePath stringByAppendingString:sourceUrl];
    NSString *standByDir = [basePath stringByAppendingString:backUpUrl];
    
    NSUserDefaults *defaultsObject = [[NSUserDefaults standardUserDefaults] retain];
    [defaultsObject setBool:NO forKey:@"updateReady"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    NSError * error = nil;
    if([fileManager fileExistsAtPath:standByDir isDirectory:&isDir] && isDir){
        if([fileManager fileExistsAtPath:carmaDir isDirectory:&isDir] && isDir){
            if([fileManager removeItemAtPath:carmaDir error:&error]){
                [fileManager moveItemAtPath:standByDir toPath:carmaDir error:&error];
                if(error != nil){
                    NSLog(@"Error move standby to carma: %@", [error localizedDescription]);
                    [self doCallback:@"INTERRUPTED"];
                    return;
                }
                else{
                    NSString* updateVersion = [defaultsObject stringForKey:@"updateVersion"];
                    [defaultsObject setValue:updateVersion forKey:@"bundleVersion"];
                    [defaultsObject synchronize];
                    [self doCallback:@"APPLIED"];
                    return;
                }
            }
            else{
                NSLog(@"Error deleting carma dir: %@", [error localizedDescription]);
                [self doCallback:@"INTERRUPTED"];
                return;
            }
        }
    }
    else{
         NSLog(@"Error standby folder does not exit");
        [self doCallback:@"INTERRUPTED"];
    }
    
    return @"";
}

-(void)doCallback:(NSString*)state
{
    if(self->m_callback){
        NSDictionary* dict = [[[NSDictionary alloc] initWithObjectsAndKeys:state, @"state", nil] autorelease];
        NSArray* array = [NSArray arrayWithObjects: dict, nil];
        [self->m_callback call:array thisObject:nil];
    }
}

@end
