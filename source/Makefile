AS = nasm
ASFLAGS = -f bin

all: kernel.bin

%.bin: %.asm
	$(AS) $(ASFLAGS) $< -o $@
