AS = nasm
ASFLAGS = -f bin

all: kernel.bin
	python pre_replace.py
	python replace.py
	python pre_replace.py
	python replace.py

%.bin: %.asm
	$(AS) $(ASFLAGS) $< -o $@
