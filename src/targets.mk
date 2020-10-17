# -*- coding: utf-8 -*-
## This Makefile provides the bodies of a variety of build targets (or
## ‘recipes’) normally used in building native executables and libraries.
## These include: debug, release, sanity check, code coverage, and address
## sanitisation tunings. Using the conventional *FILES and *FLAGS Makefile
## variables, the toolchain program variables (like ‘$(CC)’), the $(PROJECT)
## variable, and some miscellaneous helpers, it will fill out all of the
## typical details for these targets automatically, just by including it in
## the main Makefile.
## This works with both C and C++ code, and is continuously tested on macOS
## Mojave and Arch Linux.
## Read <https://aquefir.co/slick/makefiles> for details.
## This file: version 1.0.2

## DEPRECATION: <https://github.com/aquefir/slick/issues/7>
ifdef HFILES
$(warning HFILES is deprecated. Please use PUBHFILES and PRVHFILES instead)
endif
ifdef HPPFILES
$(warning HPPFILES is deprecated. Please use PUBHFILES and PRVHFILES instead)
endif

ifdef TES_HFILES
$(warning TES_HFILES is deprecated. Please use PUBHFILES and PRVHFILES instead)
endif
ifdef TES_HPPFILES
$(warning TES_HPPFILES is deprecated. Please use PUBHFILES and PRVHFILES instead)
endif

# Incorporate 3rdparty dependencies
INCLUDES += $(patsubst %,$(3PLIBDIR)/%lib/include,$(3PLIBS))
LIBDIRS  += $(patsubst %,$(3PLIBDIR)/%lib,$(3PLIBS))
LIBS     += $(3PLIBS)

# Variable transformations for command invocation
LIB := $(patsubst %,-L%,$(LIBDIRS)) $(patsubst %,-l%,$(LIBS))
ifeq ($(CC),tcc)
INCLUDE := $(patsubst %,-I%,$(INCLUDES)) $(patsubst %,-isystem %,$(INCLUDEL))
else
INCLUDE := $(patsubst %,-isystem %,$(INCLUDES)) \
	$(patsubst %,-iquote %,$(INCLUDEL))
endif
DEFINE    := $(patsubst %,-D%,$(DEFINES)) $(patsubst %,-U%,$(UNDEFINES))
FWORK     := $(patsubst %,-framework %,$(FWORKS))
ASINCLUDE := $(patsubst %,-I %,$(INCLUDES)) $(patsubst %,-I %,$(INCLUDEL))
ASDEFINE  := $(patsubst %,--defsym %=1,$(DEFINES))

# For make install
PREFIX := /usr/local

# Populated below
TARGETS :=

ifeq ($(strip $(TP)),GBA)
TESTARGETS :=
else
TESTARGETS := $(TES_CFILES:.tes.c=.c.tes) $(TES_CPPFILES:.tes.cpp=.cpp.tes)
endif

# specify all target filenames
GBATARGET := $(PROJECT).gba
EXETARGET := $(PROJECT)$(EXE)
SOTARGET  := lib$(PROJECT).$(SO)
ATARGET   := lib$(PROJECT).a

ifeq ($(strip $(TP)),GBA)
ifeq ($(strip $(EXEFILE)),1)
TARGETS += $(GBATARGET)
endif
else
ifeq ($(strip $(EXEFILE)),1)
TARGETS += $(EXETARGET)
endif
ifeq ($(strip $(SOFILE)),1)
TARGETS += $(SOTARGET)
endif
endif
ifeq ($(strip $(AFILE)),1)
TARGETS += $(ATARGET)
endif

# Use ?= so that this can be overridden. This is useful when some projects in
# a solution need $(CXX) linkage when the main project lacks any $(CPPFILES)
ifeq ($(strip $(CPPFILES)),)
	CCLD ?= $(CC)
else
	CCLD ?= $(CXX)
endif

.PHONY: debug release check cov asan ubsan clean format

## Debug build
## useful for: normal testing, valgrind, LLDB
##
debug: DEFINE += -UNDEBUG
ifneq ($(CC),tcc)
debug: CFLAGS += $(CFLAGS.GCOMMON.DEBUG)
endif # tcc
debug: CXXFLAGS += $(CXXFLAGS.COMMON.DEBUG)
debug: REALSTRIP := ':' ; # : is a no-op
debug: $(TARGETS)

## Release build
## useful for: deployment
##
release: DEFINE += -DNDEBUG=1
ifneq ($(CC),tcc)
release: CFLAGS += $(CFLAGS.GCOMMON.RELEASE)
endif # tcc
release: CXXFLAGS += $(CXXFLAGS.COMMON.RELEASE)
release: REALSTRIP := $(STRIP)
release: $(TARGETS)

## Sanity check build
## useful for: pre-tool bug squashing
##
check: DEFINE += -UNDEBUG
ifneq ($(CC),tcc)
check: CFLAGS += $(CFLAGS.GCOMMON.CHECK)
endif # tcc
check: CXXFLAGS += $(CXXFLAGS.COMMON.CHECK)
check: REALSTRIP := ':' ; # : is a no-op
check: $(TARGETS)

## Code coverage build
## useful for: checking coverage of test suite
##
cov: DEFINE += -UNDEBUG -D_CODECOV
ifneq ($(CC),tcc)
cov: CFLAGS += $(CFLAGS.GCOMMON.COV)
endif # tcc
cov: CXXFLAGS += $(CXXFLAGS.COMMON.COV)
cov: LDFLAGS += $(LDFLAGS.COV)
cov: REALSTRIP := ':' ; # : is a no-op
ifeq ($(strip $(NO_TES)),)
cov: DEFINE += -DTES_BUILD=1
cov: $(TESTARGETS)
else
cov: DEFINE += -UTES_BUILD
cov: $(TARGETS)
endif # $(NO_TES)

## Address sanitised build
## useful for: squashing memory issues
##
asan: DEFINE += -UNDEBUG -D_ASAN
ifneq ($(CC),tcc)
asan: CFLAGS += $(CFLAGS.GCOMMON.ASAN)
endif # tcc
asan: CXXFLAGS += $(CXXFLAGS.COMMON.ASAN)
asan: LDFLAGS += $(LDFLAGS.ASAN)

asan: REALSTRIP := ':' ; # : is a no-op
ifeq ($(strip $(NO_TES)),)
asan: DEFINE += -DTES_BUILD=1
ifneq ($(strip $(EXEFILE)),)
asan: $(TARGETS)
endif
asan: $(TESTARGETS)
else
asan: DEFINE += -UTES_BUILD
asan: $(TARGETS)
endif # $(NO_TES)

## Undefined Behaviour sanitised build
## useful for: squashing UB :-)
##
ubsan: DEFINE += -UNDEBUG -D_UBSAN
ifneq ($(CC),tcc)
ubsan: CFLAGS += $(CFLAGS.GCOMMON.UBSAN)
endif # tcc
ubsan: CXXFLAGS += $(CXXFLAGS.COMMON.UBSAN)
ubsan: LDFLAGS += $(LDFLAGS.UBSAN)
ubsan: REALSTRIP := ':' ; # : is a no-op
ifeq ($(strip $(NO_TES)),)
ubsan: DEFINE += -DTES_BUILD=1
ifneq ($(strip $(EXEFILE)),)
ubsan: $(TARGETS)
endif
ubsan: $(TESTARGETS)
else
ubsan: DEFINE += -UTES_BUILD
ubsan: $(TARGETS)
endif # $(NO_TES)

# Define object files
OFILES     := $(CFILES:.c=.c.o) $(CPPFILES:.cpp=.cpp.o)
ifneq ($(strip $(TP)),Darwin)
OFILES += $(SFILES:.s=.s.o)
endif
TES_OFILES := $(TES_CFILES:.c=.c.o) $(TES_CPPFILES:.cpp=.cpp.o)

# Object file builds
%.cpp.o: %.cpp
	$(CXX) -c -o $@ $(CXXFLAGS) $(DEFINE) $(INCLUDE) $<

%.c.o: %.c
	$(CC) -c -o $@ $(CFLAGS) $(DEFINE) $(INCLUDE) $<

%.s.o: %.s
	$(AS) -o $@ $(ASFLAGS) $(ASDEFINE) $(ASINCLUDE) $<

%.tes.cpp.o: %.tes.cpp
	$(CXX) -c -o $@ $(CXXFLAGS) $(INCLUDE) $<

%.tes.c.o: %.tes.c
	$(CC) -c -o $@ $(CFLAGS) $(INCLUDE) $<

%.cpp.tes: %.tes.cpp.o $(ATARGET)
	$(CCLD) $(LDFLAGS) -o $@ $^ $(LIB)

%.c.tes: %.tes.c.o $(ATARGET)
	$(CCLD) $(LDFLAGS) -o $@ $^ $(LIB)

# Static library builds
$(ATARGET): $(OFILES)
ifneq ($(strip $(OFILES)),)
	$(REALSTRIP) -s $^
	$(AR) $(ARFLAGS) $@ $^
endif

# Shared library builds
$(SOTARGET): $(OFILES)
ifneq ($(strip $(OFILES)),)
	$(CCLD) $(LDFLAGS) -shared -o $@ $^ $(LIB)
	$(REALSTRIP) -s $@
endif

# Executable builds
$(EXETARGET): $(OFILES)
ifneq ($(strip $(OFILES)),)
	$(CCLD) $(LDFLAGS) -o $@ $^ $(LIB)
	$(REALSTRIP) -s $@
endif

$(GBATARGET): $(EXETARGET)
	$(OCPY) -O binary $< $@
	$(FIX) $@ $(FIXFLAGS)

DSYMS := $(patsubst %,%.dSYM,$(TARGETS)) $(patsubst %,%.dSYM,$(TESTARGETS))

clean:
	$(RM) $(TARGETS)
	$(RM) lib$(PROJECT).dll
	$(RM) $(TESTARGETS)
	$(RM) -r $(DSYMS)
	$(RM) $(OFILES)
	$(RM) $(CFILES:.c=.c.gcno) $(CPPFILES:.cpp=.cpp.gcno)
	$(RM) $(CFILES:.c=.c.gcda) $(CPPFILES:.cpp=.cpp.gcda)
	$(RM) $(TES_OFILES)
	$(RM) $(TES_CFILES:.c=.c.gcno) $(TES_CPPFILES:.cpp=.cpp.gcno)
	$(RM) $(TES_CFILES:.c=.c.gcda) $(TES_CPPFILES:.cpp=.cpp.gcda)

ifeq ($(strip $(NO_TES)),)
format: $(TES_CFILES) $(TES_CPPFILES) $(TES_HFILES) $(TES_HPPFILES) \
	$(TES_PUBHFILES) $(TES_PRVHFILES)
endif
format: $(CFILES) $(CPPFILES) $(HFILES) $(HPPFILES) $(PUBHFILES) $(PRVHFILES)
	for _file in $^; do \
		$(FMT) -i -style=file $$_file ; \
	done
	unset _file

install: $(TARGETS)
	-[ -n "$(EXEFILE)" ] && $(INSTALL) -Dm755 $(EXETARGET) $(PREFIX)/bin/$(EXETARGET)
	-[ -n "$(SOFILE)" ] && $(INSTALL) -Dm755 $(SOTARGET) $(PREFIX)/lib/$(SOTARGET)
	-[ -n "$(AFILE)" ] && $(INSTALL) -Dm644 $(ATARGET) $(PREFIX)/lib/$(ATARGET)
	for _f in $(PUBHFILES); do \
	$(CP) -rp --parents $$_f $(PREFIX)/; done
