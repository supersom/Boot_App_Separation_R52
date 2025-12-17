# Makefile for the bootloader

# The target name is derived from the directory name
TARGET_NAME = $(notdir $(CURDIR))
ELF_OUT     = ../$(TARGET_NAME).elf

# Toolchain
CC = armclang
LD = armlink

# Flags
TARGET_FLAGS = -target=arm-arm-none-eabi -mcpu=cortex-r52 -mfloat-abi=soft -mthumb
ASFLAGS      = -g -c $(TARGET_FLAGS)
LDFLAGS      = --cpu=Cortex-R52 --map

# Auto-discover sources and create object list
# This project is pure assembly, so we only look for .S files
SRCS_S = $(wildcard *.S)
OBJS   = $(SRCS_S:.S=.o)

# Default target
.PHONY: all
all: $(ELF_OUT)

# Rule to link the final ELF
# Note the custom linker flags for this bootloader
$(ELF_OUT): $(OBJS)
	$(LD) $(LDFLAGS) --scatter=$(TARGET_NAME).scat --entry=_start -o $@ $(OBJS)

# Pattern rule to assemble .S source
%.o: %.S
	$(CC) $(ASFLAGS) $< -o $@

# Rule to clean build artifacts
.PHONY: clean
clean:
	rm -f $(OBJS) $(ELF_OUT) ../$(TARGET_NAME).map