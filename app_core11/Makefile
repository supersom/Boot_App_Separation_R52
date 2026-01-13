# Makefile for the Core 1 application

# The target name is derived from the directory name
TARGET_NAME = $(notdir $(CURDIR))
ELF_OUT     = ../$(TARGET_NAME).elf

# Toolchain
CC = armclang
LD = armlink

# Flags
TARGET_FLAGS = -target=arm-arm-none-eabi -mcpu=cortex-r52 -mfloat-abi=soft -mthumb
CFLAGS       = -g -c $(TARGET_FLAGS)
LDFLAGS      = --cpu=Cortex-R52 --map --library_type=microlib

# Auto-discover sources and create object list
SRCS_C = $(wildcard *.c)
SRCS_S = $(wildcard *.S)
OBJS   = $(SRCS_C:.c=.o) $(SRCS_S:.S=.o)

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
	$(CC) $(CFLAGS) $< -o $@

# Rule to clean build artifacts
.PHONY: clean
clean:
	rm -f $(OBJS) $(ELF_OUT) ../$(TARGET_NAME).map
