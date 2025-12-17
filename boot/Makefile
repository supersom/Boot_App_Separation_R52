# Makefile for the bootloader

# Toolchain
CC = armclang
LD = armlink

# Common compiler and linker flags from your build command
TARGET_FLAGS   = -target=arm-arm-none-eabi -mcpu=cortex-r52 -mfloat-abi=soft -mthumb
CFLAGS         = -g -c $(TARGET_FLAGS)
LDFLAGS        = --cpu=Cortex-R52 --map --library_type=microlib

# Output file (in the parent directory)
ELF_OUT = ../boot.elf

# Source and Object files
SRC_S = startup.S
OBJS  = $(SRC_S:.S=.o)

# Default target
.PHONY: all
all: $(ELF_OUT)

# Rule to link the final ELF
$(ELF_OUT): $(OBJS)
	$(LD) $(LDFLAGS) --scatter=boot.scat --entry=_start -o $@ $(OBJS)

# Rule to compile assembly
%.o: %.S
	$(CC) $(CFLAGS) $< -o $@

# Rule to clean build artifacts
.PHONY: clean
clean:
	rm -f $(OBJS) $(ELF_OUT) ../boot.map
