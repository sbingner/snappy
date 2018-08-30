target ?= iphone:clang:11.0:11.0
ARCHS ?= arm64
DEBUG ?= no
include $(THEOS)/makefiles/common.mk

TOOL_NAME = snappy
snappy_FILES = snappy.m
snappy_FRAMEWORKS = IOKit
snappy_CODESIGN_FLAGS = -Sentitlements.xml

after-stage::
	$(ECHO_NOTHING)chmod u+s $(FW_STAGING_DIR)/usr/bin/snappy$(ECHO_END)

include $(THEOS_MAKE_PATH)/tool.mk
