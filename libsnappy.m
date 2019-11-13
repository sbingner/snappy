/* Copyright 2018-2019 Sam Bingner All Rights Reserved
 */
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/snapshot.h>
#include <strings.h>
#include <getopt.h>
#import <CoreFoundation/CoreFoundation.h>
#if __has_include(<IOKit/IOKit.h>)
#include <IOKit/IOKit.h>
#else
#include <mach/error.h>
typedef mach_port_t     io_object_t;
typedef io_object_t     io_registry_entry_t;
typedef char            io_string_t[512];
typedef UInt32          IOOptionBits;

extern const mach_port_t kIOMasterPortDefault;

io_registry_entry_t IORegistryEntryFromPath(mach_port_t masterPort, const io_string_t path);
CFTypeRef IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options);
kern_return_t IOObjectRelease(io_object_t object );
#endif
#include "snappy.h"

static char *copyBootHash(void);
#define APPLESNAP "com.apple.os.update-"

__attribute__((aligned(4)))
typedef struct val_attrs {
	uint32_t		length;
	attribute_set_t		returned;
	attrreference_t		name_info;
	char			name[MAXPATHLEN];
} val_attrs_t;

bool snapshot_check(int dirfd, const char *name)
{
    const char **snapshots = copy_snapshot_list(dirfd);
    if (snapshots == NULL) {
        return false;
    }
    for (const char **snapshot = snapshots; *snapshot; snapshot++) {
        if (strcmp(name, *snapshot)==0) {
            free(snapshots);
            return true;
        }
    }
    free(snapshots);
    return false;
}

const char *copy_first_snapshot(int dirfd)
{
    char *snapshot = NULL;

    const char **snapshots = copy_snapshot_list(dirfd);
    if (!snapshots) return NULL;
    if (snapshots[0]) {
        snapshot = strdup(snapshots[0]);
    }
    free(snapshots);
    return snapshot;
}

const char **copy_snapshot_list(int dirfd)
{
	uint64_t nameOffset = 257 * sizeof(char *);
	uint64_t snapshots_size = nameOffset + MAXPATHLEN;
	char **snapshots = (char **)calloc(snapshots_size, sizeof(char));
	struct attrlist attr_list = { 0 };

        if (snapshots == NULL) {
            perror("Unable to allocate memory for snapshot names");
            return NULL;
        }

	attr_list.commonattr = ATTR_BULK_REQUIRED;

	val_attrs_t buf;
	bzero(&buf, sizeof(buf));
	int retcount;
	int snapidx = 0;
	while ((retcount = fs_snapshot_list(dirfd, &attr_list, &buf, sizeof(buf), 0))>0) {
		val_attrs_t *entry = &buf;

                int i;
                for (i=0; i<retcount; i++) {
			if (entry->returned.commonattr & ATTR_CMN_NAME) {
				size_t size = strlen(entry->name) + 1;
				if (snapidx > 255) {
					fprintf(stderr, "Too many snapshots to handle\n");
					return (const char **)snapshots;
				}
				if (nameOffset + size > snapshots_size) {
					snapshots_size += MAXPATHLEN;
					snapshots = (char **)reallocf(snapshots, snapshots_size);
                                        if (snapshots == NULL) {
                                            perror("Couldn't realloc snapshot buffer");
                                            return NULL;
                                        }
				}
				snapshots[snapidx] = (char *)snapshots + nameOffset;
				nameOffset += size;
				strncpy(snapshots[snapidx], entry->name, size);
                                snapidx++;
                        }

			entry = (val_attrs_t *)((char *)entry + entry->length);
		}
                bzero(&buf, sizeof(buf));
        }

	if (retcount < 0) {
		perror("fs_snapshot_list");
		return nil;
	}

	return (const char **)snapshots;
}

static int sha1_to_str(const unsigned char *hash, size_t hashlen, char *buf, size_t buflen)
{
	if (buflen < (hashlen*2+1)) {
		return -1;
	}

	int i;
	for (i=0; i<hashlen; i++) {
		sprintf(buf+i*2, "%02X", hash[i]);
	}
	buf[i*2] = 0;
	return ERR_SUCCESS;
}

static char *copyBootHash(void)
{
	io_registry_entry_t chosen = IORegistryEntryFromPath(kIOMasterPortDefault, "IODeviceTree:/chosen");

	if (!MACH_PORT_VALID(chosen)) {
		printf("Unable to get IODeviceTree:/chosen port\n");
		return NULL;
	}

	CFDataRef hash = (CFDataRef)IORegistryEntryCreateCFProperty(chosen, CFSTR("boot-manifest-hash"), kCFAllocatorDefault, 0);

	IOObjectRelease(chosen);

	if (hash == nil) {
		fprintf(stderr, "Unable to read boot-manifest-hash\n");
		return NULL;
	}

	if (CFGetTypeID(hash) != CFDataGetTypeID()) {
		fprintf(stderr, "Error hash is not data type\n");
		CFRelease(hash);
		return NULL;
	}

	// Make a hex string out of the hash

	CFIndex length = CFDataGetLength(hash) * 2 + 1;
	char *manifestHash = (char*)calloc(length, sizeof(char));

	int ret = sha1_to_str(CFDataGetBytePtr(hash), CFDataGetLength(hash), manifestHash, length);

	CFRelease(hash);

	if (ret != ERR_SUCCESS) {
		printf("Unable to generate bootHash string\n");
		free(manifestHash);
		return NULL;
	}

	return manifestHash;
}

char *copy_system_snapshot()
{
    char *hash = copyBootHash();
    if (hash == NULL) {
        return NULL;
    }
    char *hashsnap = malloc(strlen(APPLESNAP) + strlen(hash) + 1);
    strcpy(hashsnap, APPLESNAP);
    strcpy(hashsnap + strlen(APPLESNAP), hash);
    free(hash);
    return hashsnap;
}

@implementation SBSnappy : NSObject
int fd=-1;

+(SBSnappy*)snappyWithPath:(NSString*)path {
    return [[[SBSnappy alloc] initWithPath:path] autorelease];
}

+(NSString*)systemSnapshot {
    char *snapName = copy_system_snapshot();
    if (!snapName) {
        return nil;
    }

    NSString *snap = [[NSString alloc] initWithBytesNoCopy:snapName length:strlen(snapName) encoding:NSUTF8StringEncoding freeWhenDone:YES];
    return [snap autorelease];
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
    return [[snapshots copy] autorelease];
}

-(NSString*)firstSnapshot {
    const char *snapName = copy_first_snapshot(fd);
    if (!snapName) {
        return nil;
    }

    NSString *snap = [[NSString alloc] initWithBytesNoCopy:(char*)snapName length:strlen(snapName) encoding:NSUTF8StringEncoding freeWhenDone:YES];
    return [snap autorelease];
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
    [super dealloc];
    if (fd >= 0) {
        close(fd);
        fd = -1;
    }
}

@end
