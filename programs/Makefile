AS = nasm
ASFLAGS = -f bin

OBJECTS = cls.bin dir.bin dir2.bin fm.bin ls.bin pwd.bin snake.bin vsnake.bin date.bin fsize.bin

all: $(OBJECTS)

%.bin: %.asm
	$(AS) $(ASFLAGS) $< -o $@
