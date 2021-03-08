/* Copyright 2018-2019 Sam Bingner All Rights Reserved
 */
#include <mach/error.h>
#include <sys/snapshot.h>
#include "snappy.h"

@implementation SBSnappy : NSObject
int fd=-1;

+(SBSnappy*)snappyWithPath:(NSString*)path {
#if __has_feature(objc_arc)
    return [[SBSnappy alloc] initWithPath:path];
#else
    return [[[SBSnappy alloc] initWithPath:path] autorelease];
#endif
}

+(NSString*)systemSnapshot {
    char *snapName = copy_system_snapshot();
    if (!snapName) {
        return nil;
    }

    NSString *snap = [[NSString alloc] initWithBytesNoCopy:snapName length:strlen(snapName) encoding:NSUTF8StringEncoding freeWhenDone:YES];
#if __has_feature(objc_arc)
    return snap;
#else
    return [snap autorelease];
#endif
}

-(SBSnappy*)initWithPath:(NSString*)path {
    self = [super init];
    if (fd >= 0)
        close(fd);

    fd = open(path.UTF8String, O_RDONLY);
    if (fd < 0) {
        return nil;
    }
    return self;
}

-(BOOL)hasSnapshot:(NSString*)snapshot {
    if (fd < 0) {
        NSLog(@"hasSnapshot called with no path set");
        return NO;
    }

    return snapshot_check(fd, snapshot.UTF8String);
}

-(NSArray <NSString*> *)snapshots {
    if (fd < 0) {
        NSLog(@"hasSnapshot called with no path set");
        return nil;
    }
    const char **snaps = copy_snapshot_list(fd);
    if (snaps == NULL)
        return nil;

    NSMutableArray *snapshots = [NSMutableArray new];
    for (const char **snap = snaps; *snap; snap++) {
        [snapshots addObject:@(*snap)];
    }
    free(snaps);
#if __has_feature(objc_arc)
    return [snapshots copy];
#else
    return [[snapshots copy] autorelease];
#endif
}

-(NSString*)firstSnapshot {
    const char *snapName = copy_first_snapshot(fd);
    if (!snapName) {
        return nil;
    }

    NSString *snap = [[NSString alloc] initWithBytesNoCopy:(char*)snapName length:strlen(snapName) encoding:NSUTF8StringEncoding freeWhenDone:YES];
#if __has_feature(objc_arc)
    return snap;
#else
    return [snap autorelease];
#endif
}

-(BOOL)create:(NSString*)name {
    return fs_snapshot_create(fd, name.UTF8String, 0) == ERR_SUCCESS;
}

-(BOOL)delete:(NSString*)name {
    return fs_snapshot_delete(fd, name.UTF8String, 0) == ERR_SUCCESS;
}

-(BOOL)rename:(NSString*)name to:(NSString*)newName {
    return fs_snapshot_rename(fd, name.UTF8String, newName.UTF8String, 0) == ERR_SUCCESS;
}

-(BOOL)renameToStock {
    NSString *firstSnap = [self firstSnapshot];
    NSLog(@"firstSnap: %@", firstSnap);
    if (!firstSnap) return NO;

    NSString *systemSnap = [SBSnappy systemSnapshot];
    NSLog(@"systemSnap: %@", systemSnap);
    if (!systemSnap) return NO;

    return [self rename:firstSnap to:systemSnap];
}

-(BOOL)mount:(NSString*)name to:(NSString*)path withFlags:(uint32_t)flags {
    return fs_snapshot_mount(fd, path.UTF8String, name.UTF8String, flags) == ERR_SUCCESS;
}

-(BOOL)mount:(NSString*)name to:(NSString*)path {
    return [self mount:name to:path withFlags:0];
}

-(BOOL)revert:(NSString*)name {
    return fs_snapshot_revert(fd, name.UTF8String, 0) == ERR_SUCCESS;
}

-(void)dealloc {
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
    if (fd >= 0) {
        close(fd);
        fd = -1;
    }
}

@end
