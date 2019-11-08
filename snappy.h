/* Copyright 2018 Sam Bingner All Rights Reserved
	 */

#ifndef _SNAPPY_H
#define _SNAPPY_H

#ifdef __OBJC__
@interface SBSnappy : NSObject
@property (readonly) NSArray <NSString*> *snapshots;

+(SBSnappy*)snappyWithPath:(NSString*)path;
+(NSString*)systemSnapshot;
-(SBSnappy*)initWithPath:(NSString*)path;
-(BOOL)hasSnapshot:(NSString*)snapshot;
-(NSArray <NSString*> *)snapshots;
-(BOOL)create:(NSString*)name;
-(BOOL)delete:(NSString*)name;
-(BOOL)rename:(NSString*)name to:(NSString*)newName;
-(BOOL)mount:(NSString*)name to:(NSString*)path;
-(BOOL)revert:(NSString*)name;
@end
#endif

const char **snapshot_list(int dirfd);
bool snapshot_check(int dirfd, const char *name);
char *copySystemSnapshot(void);

#endif
