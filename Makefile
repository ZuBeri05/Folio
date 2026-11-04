#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>/devkitpro")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITPRO)/libnx/switch_rules

#---------------------------------------------------------------------------------
TARGET      := folio
BUILD       := build
SOURCES     := source source/core source/domain source/data source/services \
               source/ui source/platform
DATA        := res
INCLUDES    := source
ROMFS       := res

APP_TITLE   := Folio
APP_AUTHOR  := Folio
APP_VERSION := 1.1.2

#---------------------------------------------------------------------------------
ARCH    := -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIE

CFLAGS  := -g -Wall -O2 -ffunction-sections -fdata-sections \
           $(ARCH) $(DEFINES)

CFLAGS  += $(INCLUDE) -D__SWITCH__

CXXFLAGS := $(CFLAGS) -fno-rtti -std=gnu++17

LDFLAGS = -specs=$(DEVKITPRO)/libnx/switch.specs -g $(ARCH) -Wl,-Map,$(notdir $*.map)

# switch_rules picks LD from base_rules, which resolves to the host linker for a
# C++-only project; pin the whole toolchain to DEVKITPRO/devkitA64 (DEVKITA64 is
# not exported by the official rules, so derive it here).
DEVKITA64 := $(DEVKITPRO)/devkitA64
export CC  := $(DEVKITA64)/bin/aarch64-none-elf-gcc
export CXX := $(DEVKITA64)/bin/aarch64-none-elf-g++
export LD  := $(DEVKITA64)/bin/aarch64-none-elf-g++
export AS  := $(DEVKITA64)/bin/aarch64-none-elf-as
export AR  := $(DEVKITA64)/bin/aarch64-none-elf-ar
export NM  := $(DEVKITA64)/bin/aarch64-none-elf-nm

LIBS    := -lnx

LIBDIRS := $(PORTLIBS) $(LIBNX)

#---------------------------------------------------------------------------------
ifneq ($(BUILD),$(notdir $(CURDIR)))
#---------------------------------------------------------------------------------

export OUTPUT := $(CURDIR)/$(TARGET)
export TOPDIR := $(CURDIR)

export VPATH := $(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
                $(foreach dir,$(DATA),$(CURDIR)/$(dir))

export DEPSDIR := $(CURDIR)/$(BUILD)

CFILES   := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
SFILES   := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))

export OFILES_BIN := $(addsuffix .o,$(BINFILES))
export OFILES_SRC := $(CPPFILES:.cpp=.o) $(CFILES:.c=.o) $(SFILES:.s=.o)
export OFILES     := $(OFILES_BIN) $(OFILES_SRC)
export HFILES_BIN := $(addsuffix .h,$(subst .,_,$(BINFILES)))

export INCLUDE := $(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
                  $(foreach dir,$(LIBDIRS),-I$(dir)/include) \
                  -I$(CURDIR)/$(BUILD)
export LIBPATHS := $(foreach dir,$(LIBDIRS),-L$(dir)/lib)

.PHONY: $(BUILD) clean all

all: $(BUILD)

$(BUILD):
	@[ -d $@ ] || mkdir -p $@
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).nro $(TARGET).elf $(TARGET).nacp

#---------------------------------------------------------------------------------
else
DEPENDS := $(OFILES:.o=.d)

#---------------------------------------------------------------------------------
all: $(OUTPUT).nro

$(OUTPUT).nro : $(OUTPUT).elf $(OUTPUT).nacp
	elf2nro $< $@ --romfsdir="$(TOPDIR)/$(ROMFS)" --nacp="$(OUTPUT).nacp" --icon="$(APP_ICON)"
$(OUTPUT).elf : $(OFILES)

-include $(DEPENDS)
#---------------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------------
