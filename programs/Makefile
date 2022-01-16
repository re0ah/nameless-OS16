AS = nasm
ASFLAGS = -f bin

OBJECTS = cls.bin dir.bin fm.bin ls.bin pwd.bin snake.bin date.bin fstat.bin pong.bin settz.bin xtc.bin reboot.bin help.bin newfile.bin

all: $(OBJECTS)

%.bin: %.asm
	$(AS) $(ASFLAGS) $< -o $@
