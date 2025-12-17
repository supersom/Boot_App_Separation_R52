# Makefile for the Core 1 application

# Toolchain
CC = armclang
LD = armlink

# Common compiler and linker flags
TARGET_FLAGS   = -target=arm-arm-none-eabi -mcpu=cortex-r52 -mfloat-abi=soft -mthumb
CFLAGS         = -g -c $(TARGET_FLAGS)
LDFLAGS        = --cpu=Cortex-R52 --map --library_type=microlib

# Output file (in the parent directory)
ELF_OUT = ../app_core1.elf

# Source and Object files
SRC_C = app_core1.c
OBJS  = $(SRC_C:.c=.o)

# Default target
.PHONY: all
all: $(ELF_OUT)

# Rule to link the final ELF
$(ELF_OUT): $(OBJS)
	$(LD) $(LDFLAGS) --scatter=app_core1.scat --entry=__main -o $@ $(OBJS)

# Rule to compile C source
%.o: %.c
	$(CC) $(CFLAGS) $< -o $@

# Rule to clean build artifacts
.PHONY: clean
clean:
	rm -f $(OBJS) $(ELF_OUT) ../app_core1.map
