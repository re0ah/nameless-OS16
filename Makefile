AS = nasm
ASFLAGS = -f bin

all: os16.iso

BOOTLOADER = source/bootload
KERNEL = source/
PROGRAMS = programs

os16.flp: clean
	@$(MAKE) -C $(BOOTLOADER)
	@$(MAKE) -C $(KERNEL)
	@$(MAKE) -C $(PROGRAMS)
	rm -rf images
	mkdir images
	mkdosfs -C images/os16.flp 1440
	dd status=noxfer conv=notrunc if=source/bootload/bootload.bin of=images/os16.flp || exit
	rm -rf tmp-loop
	mkdir tmp-loop && mount -o loop -t vfat images/os16.flp tmp-loop && cp source/kernel.bin tmp-loop/
	cp programs/*.bin tmp-loop
	sleep 0.2
	umount tmp-loop || exit
	rm -rf tmp-loop

os16.iso: os16.flp
	rm -f images/os16.iso
	mkisofs -quiet -V 'os16' -input-charset iso8859-1 -o images/os16.iso -b os16.flp images

run: os16.iso
	qemu-system-i386 -cdrom images/os16.iso

%.bin: %.asm
	$(AS) $(ASFLAGS) $< -o $@

clean:
	rm -rf source/*.bin
	rm -rf source/bootload/*.bin
	rm -rf programs/*.bin
	rm -rf images
