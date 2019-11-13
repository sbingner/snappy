/* Copyright 2018 Sam Bingner All Rights Reserved
	 */

#ifndef _SNAPPY_H
#define _SNAPPY_H

#ifdef __OBJC__
#import <Foundation/Foundation.h>
@interface SBSnappy : NSObject
@property (readonly) NSArray<NSString*> *snapshots;

+(SBSnappy*)snappyWithPath:(NSString*)path;
+(NSString*)systemSnapshot;
-(SBSnappy*)initWithPath:(NSString*)path;
-(BOOL)hasSnapshot:(NSString*)snapshot;
-(NSArray<NSString*> *)snapshots;
-(NSString*)firstSnapshot;
-(BOOL)create:(NSString*)name;
-(BOOL)delete:(NSString*)name;
-(BOOL)rename:(NSString*)name to:(NSString*)newName;
-(BOOL)renameToStock;
-(BOOL)mount:(NSString*)name to:(NSString*)path withFlags:(uint32_t)flags;
-(BOOL)mount:(NSString*)name to:(NSString*)path;
-(BOOL)revert:(NSString*)name;
@end
#endif

const char **copy_snapshot_list(int dirfd);
const char *copy_first_snapshot(int dirfd);
bool snapshot_check(int dirfd, const char *name);
char *copy_system_snapshot(void);

#endif
