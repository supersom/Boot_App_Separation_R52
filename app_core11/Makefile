# Makefile for the Core 1 application

# The target name is derived from the directory name
TARGET_NAME = $(notdir $(CURDIR))
ELF_OUT     = ../$(TARGET_NAME).elf
MAP_OUT     = ../$(TARGET_NAME).map

# Toolchain
CC = armclang
LD = armlink

# Flags
CPU = cortex-r52
CODE_TYPE = thumb
TARGET_ARCH = --target=arm-arm-none-eabi -mcpu=$(CPU) -mfpu=neon-fp-armv8 -mfloat-abi=hard -m$(CODE_TYPE) # Used for .c
TARGET_MACH = $(TARGET_ARCH) # Used for .S
CFLAGS       = -g -c $(TARGET_ARCH) -I../shared
ASFLAGS      = -g -c $(TARGET_MACH) -I../shared
LDFLAGS      = --cpu=Cortex-R52 --map --list=$(MAP_OUT) --library_type=microlib

# Auto-discover sources and create object list
SRCS_C = $(wildcard *.c)
SRCS_S = $(wildcard *.S)
SHARED_DIR = ../shared
SHARED_SRCS_S = $(wildcard $(SHARED_DIR)/*.S)
SHARED_OBJS = $(patsubst $(SHARED_DIR)/%.S, shared_%.o, $(SHARED_SRCS_S))
OBJS   = $(SRCS_C:.c=.o) $(SRCS_S:.S=.o) $(SHARED_OBJS)

# Default target
.PHONY: all
all: $(ELF_OUT)

# Rule to link the final ELF
$(ELF_OUT): $(OBJS)
	$(LD) $(LDFLAGS) --scatter=$(TARGET_NAME).scat --entry=app_bootloader -o $@ $(OBJS)

# Pattern rule to compile C source
%.o: %.c
	$(CC) $(CFLAGS) $< -o $@

# Pattern rule to assemble .S source
%.o: %.S
	$(CC) $(ASFLAGS) $< -o $@

shared_%.o: $(SHARED_DIR)/%.S
	$(CC) $(ASFLAGS) $< -o $@

# Rule to clean build artifacts
.PHONY: clean
clean:
	rm -f $(OBJS) $(ELF_OUT) ../$(TARGET_NAME).map
