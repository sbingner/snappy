target ?= iphone:clang:11.0:11.0
ARCHS ?= arm64
include $(THEOS)/makefiles/common.mk

TOOL_NAME = snappy
snappy_FILES = snappy.m
snappy_FRAMEWORKS = IOKit
snappy_CODESIGN_FLAGS = -Sentitlements.xml

include $(THEOS_MAKE_PATH)/tool.mk
