AS = nasm
ASFLAGS = -f bin

all: bootload.bin

%.bin: %.asm
	$(AS) $(ASFLAGS) $< -o $@
