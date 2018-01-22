CC                  = mips64-gcc
CXX                 = mips64-g++
LD                  = mips64-g++
OBJCOPY             = mips64-objcopy
LDSCRIPT            = gl-n64.ld
CFLAGS              = -std=gnu11 -Wall -O3 -ffunction-sections -fdata-sections -flto -ffat-lto-objects
CXXFLAGS            = -std=gnu++14 -Wall -O3 -ffunction-sections -fdata-sections -flto -ffat-lto-objects
CPPFLAGS            =
LDFLAGS             = -T $(LDSCRIPT) -nostartfiles -specs=nosys.specs -O3 -flto -Wl,--gc-sections
LDLIBS              =
CFLAGS_DEBUG        = -std=gnu11 -Wall -Og -g -ffunction-sections -fdata-sections
CXXFLAGS_DEBUG      = -std=gnu++14 -Wall -Og -g -ffunction-sections -fdata-sections
CPPFLAGS_DEBUG      =
LDFLAGS_DEBUG       = -T $(LDSCRIPT) -nostartfiles -specs=nosys.specs -Wl,--gc-sections
LDLIBS_DEBUG        =
GZ_VERSIONS         = mm-1.0-j mm-1.0-u
SRCDIR              = src
OBJDIR              = obj
BINDIR              = bin
CFILES              = *.c
CXXFILES            = *.cpp *.cxx *.cc *.c++

gz-mm-1.0-j         : CPPFLAGS       += -DZ64_VERSION=Z64_MM10J
gz-mm-1.0-j         : GZ_ADDRESS      = 801CC630
gz-mm-1.0-j-debug   : CPPFLAGS_DEBUG += -DZ64_VERSION=Z64_MM10J
gz-mm-1.0-j-debug   : GZ_ADDRESS      = 801CC630

gz-mm-1.0-u         : CPPFLAGS       += -DZ64_VERSION=Z64_MM10U
gz-mm-1.0-u         : GZ_ADDRESS      = 801D1E80
gz-mm-1.0-u-debug   : CPPFLAGS_DEBUG += -DZ64_VERSION=Z64_MM10U
gz-mm-1.0-u-debug   : GZ_ADDRESS      = 801D1E80

GZ                  = $(foreach v,$(GZ_VERSIONS),gz-$(v))
GZ-DEBUG            = $(foreach v,$(GZ_VERSIONS),gz-$(v)-debug)
all                 : $(GZ)
clean               :
	rm -rf $(OBJDIR) $(BINDIR)
.PHONY              : all clean

.SECONDEXPANSION    :

define bin_template =
 NAME-$(1)          = $(2)
 SRCDIR-$(1)        = $(3)
 OBJDIR-$(1)        = $(4)
 BINDIR-$(1)        = $(5)
 CSRC-$(1)         := $$(foreach s,$$(CFILES),$$(wildcard $$(SRCDIR-$(1))/$$(s)))
 CXXSRC-$(1)       := $$(foreach s,$$(CXXFILES),$$(wildcard $$(SRCDIR-$(1))/$$(s)))
 COBJ-$(1)          = $$(patsubst $$(SRCDIR-$(1))/%,$$(OBJDIR-$(1))/%.o,$$(CSRC-$(1)))
 CXXOBJ-$(1)        = $$(patsubst $$(SRCDIR-$(1))/%,$$(OBJDIR-$(1))/%.o,$$(CXXSRC-$(1)))
 OBJ-$(1)           = $$(COBJ-$(1)) $$(CXXOBJ-$(1))
 DEPS-$(1)          = $$(patsubst %.o,%.d,$$(OBJ-$(1)))
 BIN-$(1)           = $$(BINDIR-$(1))/$$(NAME-$(1)).bin
 ELF-$(1)           = $$(BINDIR-$(1))/$$(NAME-$(1)).elf
 BUILD-$(1)         = $(1) $(1)-debug
 CLEAN-$(1)         = clean$(1) clean$(1)-debug
 -include $$(DEPS-$(1))
 $(1)-debug         : CFLAGS    = $$(CFLAGS_DEBUG)
 $(1)-debug         : CXXFLAGS  = $$(CXXFLAGS_DEBUG)
 $(1)-debug         : CPPFLAGS  = $$(CPPFLAGS_DEBUG)
 $(1)-debug         : LDFLAGS   = $$(LDFLAGS_DEBUG)
 $(1)-debug         : LDLIBS    = $$(LDLIBS_DEBUG)
 $$(BUILD-$(1))     : LDFLAGS  += -Wl,--defsym,start=0x$$(GZ_ADDRESS)
 $$(BUILD-$(1))     : $$(BIN-$(1))
 $$(CLEAN-$(1))     :
	rm -rf $$(OBJDIR-$(1)) $$(BINDIR-$(1))
 .PHONY             : $$(BUILD-$(1)) $$(CLEAN-$(1))
 $$(BIN-$(1))       : $$(ELF-$(1)) | $$$$(dir $$$$@)
	$$(OBJCOPY) -S -O binary $$< $$@
 $$(ELF-$(1))       : $$(OBJ-$(1)) | $$$$(dir $$$$@)
	$$(LD) $$(LDFLAGS) $$^ $$(LDLIBS) -o $$@
 $$(COBJ-$(1))      : $$(OBJDIR-$(1))/%.o: $$(SRCDIR-$(1))/% | $$$$(dir $$$$@)
	$$(CC) -c -MMD -MP $$(CPPFLAGS) $$(CFLAGS) $$< -o $$@
 $$(CXXOBJ-$(1))    : $$(OBJDIR-$(1))/%.o: $$(SRCDIR-$(1))/% | $$$$(dir $$$$@)
	$$(CXX) -c -MMD -MP $$(CPPFLAGS) $$(CXXFLAGS) $$< -o $$@
 $$(RESOBJ-$(1))    : $$(OBJDIR-$(1))/$$(RESDIR)/%.o: $$(RESDIR-$(1))/% $$(RESDESC) | $$$$(dir $$$$@)
	$$(GRC) $$< -d $$(RESDESC) -o $$@

endef

$(foreach v,$(GZ_VERSIONS),$(eval \
 $(call bin_template,gz-$(v),gz,$(SRCDIR),$(OBJDIR)/$(v),$(BINDIR)/$(v)) \
))

%/                  :
	mkdir -p $@
