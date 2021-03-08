target ?= iphone:clang:latest:10.0
ARCHS ?= arm64 armv7
DEBUG ?= no
THEOS ?= theos
include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libsnappy
libsnappy_FILES = libsnappy.c libsnappy.m
libsnappy_CFLAGS = -fobjc-arc
libsnappy_FRAMEWORKS = IOKit
libsnappy_LDFLAGS = -compatibility_version 1.0.0 -current_version $(THEOS_PACKAGE_BASE_VERSION)

TOOL_NAME = snappy
snappy_FILES = snappy.c
snappy_LDFLAGS = -L$(THEOS_OBJ_DIR) -lsnappy
snappy_CODESIGN_FLAGS = -Sentitlements.xml
snappy_FRAMEWORKS = IOKit

after-stage::
	$(ECHO_NOTHING)chmod u+s $(THEOS_STAGING_DIR)/usr/bin/snappy$(ECHO_END)
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/usr/include$(ECHO_END)
	$(ECHO_NOTHING)cp snappy.h $(THEOS_STAGING_DIR)/usr/include$(ECHO_END)

include $(THEOS_MAKE_PATH)/library.mk
include $(THEOS_MAKE_PATH)/tool.mk
