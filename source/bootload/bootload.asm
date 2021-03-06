;==================================================================
;The Mike Operating System bootloader
;Copyright (C) 2006 - 2014 MikeOS Developers -- see doc/LICENSE.TXT
;
;Based on a free boot loader by E Dehling.

bits 16 ;real mode

;--------------------------DISK CONSTANTS--------------------------------------
;------------------------------------------------------------------------------
DISK_SIZE_BYTES equ 1474560
;------------------------------------------------------------------------------
BYTES_PER_SECTOR equ 512
;------------------------------------------------------------------------------
SECTORS_PER_CLUSTER equ 1
;------------------------------------------------------------------------------
SECTORS_RESERVED_FOR_BOOT equ 1
;------------------------------------------------------------------------------
NUM_OF_FATS equ 2
;------------------------------------------------------------------------------
FAT12_NAME_SIZE equ 8
;------------------------------------------------------------------------------
FAT12_EXT_SIZE equ 3
;------------------------------------------------------------------------------
FAT12_FULLNAME_SIZE equ FAT12_NAME_SIZE + FAT12_EXT_SIZE
;------------------------------------------------------------------------------
NUM_OF_ENTRIES_ROOT_DIR equ 224
;------------------------------------------------------------------------------
DIR_ENTRY_SIZE equ 32 ;in bytes
;------------------------------------------------------------------------------
ROOT_DIR_SIZE equ NUM_OF_ENTRIES_ROOT_DIR * DIR_ENTRY_SIZE
;------------------------------------------------------------------------------
ROOT_DIR_END equ ROOT_DIR_SIZE + DISK_BUFFER
;------------------------------------------------------------------------------
SECTORS_TO_ROOT_DIR equ (NUM_OF_ENTRIES_ROOT_DIR * DIR_ENTRY_SIZE) / \
													BYTES_PER_SECTOR ;14
;------------------------------------------------------------------------------
NUM_OF_LOGIC_SECTORS equ DISK_SIZE_BYTES / BYTES_PER_SECTOR ;2880
;------------------------------------------------------------------------------
TYPE_OF_DISK equ 0xF0 ;3.5-inch (90 mm) Double Sided, 80 tracks per side,
			 	  ;18 or 36 sectors per track (1440 KB, known as “1.44 MB”)
;------------------------------------------------------------------------------
SECTORS_PER_FAT equ 9
;------------------------------------------------------------------------------
SECTORS_PER_TRACK equ 18
;------------------------------------------------------------------------------
SIDES_AND_HEADS equ 2
;------------------------------------------------------------------------------
NUM_HIDDEN_SECTORS equ 0
;------------------------------------------------------------------------------
NUM_LARGE_SECTORS equ 0
;------------------------------------------------------------------------------
DRIVE_NUMBER equ 0 ;0 for floppy, 0x80 for hdd
;------------------------------------------------------------------------------
SIGNATURE equ 0x29
;------------------------------------------------------------------------------
VOLUME_ID equ 0 ;ignore that

jmp start
;-------------------------Disk description table-------------------------------------
;------------------------------DOS 4.0 EBPB------------------------------------------
OEMLabel          db "re0ah____"				;offset: 0x00..0x08
BytesPerSector	  dw BYTES_PER_SECTOR			;offset: 0x09..0x0A
SectorsPerCluster db SECTORS_PER_CLUSTER		;offset: 0x0B
ReservedForBoot   dw SECTORS_RESERVED_FOR_BOOT	;offset: 0x0C..0x0D
NumberOfFats      db NUM_OF_FATS				;offset: 0x0E
RootDirEntries    dw NUM_OF_ENTRIES_ROOT_DIR 	;offset: 0x0F..0x10
LogicalSectors    dw NUM_OF_LOGIC_SECTORS 		;offset: 0x11..0x12
MediumByte   	  db TYPE_OF_DISK				;offset: 0x13
SectorsPerFat     dw SECTORS_PER_FAT			;offset: 0x14..0x15
SectorsPerTrack   dw SECTORS_PER_TRACK			;offset: 0x16..0x17
Sides   		  dw SIDES_AND_HEADS			;offset: 0x18..0x19
HiddenSectors     dd NUM_HIDDEN_SECTORS			;offset: 0x1A..0x0D
LargeSectors      dd NUM_LARGE_SECTORS			;offset: 0x1E..0x21
DriveNo   		  db DRIVE_NUMBER				;offset: 0x22
Reserved	   	  db 0							;offset: 0x23
Signature   	  db SIGNATURE					;offset: 0x24
VolumeID	   	  dd VOLUME_ID					;offset: 0x25..0x28
VolumeLabel   	  db "lbl        "				;offset: 0x29..0x33
FileSystem   	  db "FAT12   "					;offset: 0x34..0x3B
;------------------End of disk description table-------------------------------
;------------------------------------------------------------------------------
KERNEL_FILENAME	db "KERNEL  BIN"
KERNEL_SEGMENT	equ 0x50 ;IVT_SIZE + BIOS_DATA = 0x500 bytes, with considering
						 ;4 bits shift right segment for make address kernel
						 ;will be placed behind bios data

DISK_ERROR		db "Floppy error", 0
FILE_NOT_FOUND	db "KERNEL.BIN not found", 0
;------------------------------------------------------------------------------
start:
;DISK_BUFFER located at 0x09C0 segment
;init stack (ss=0x0BC0, above 8k from DISK_BUFFER, and sp=0x0BC0 (no matter)
	mov		ax,		0x0BC0
	mov		ss,		ax
	mov		sp,		ax
;BIOS load bootloader to 0x07C0:0x0000 addr
	mov		ax,		0x07C0
	mov		ds,		ax

	mov		byte[BOOT_DEVICE],	dl	;BIOS passes boot device in dl, save it

;load root directory from disk
START_OF_ROOT equ SECTORS_RESERVED_FOR_BOOT + \
                    (NUM_OF_FATS * SECTORS_PER_FAT) ;19
;------------------------------------------------------------------------------
START_USER_DATA equ START_OF_ROOT + SECTORS_TO_ROOT_DIR ;33
;------------------------------------------------------------------------------
	mov		ax,		START_OF_ROOT
	call	l2hts

	;https://en.wikipedia.org/wiki/INT_13H
;	mov		ah,		0x02			;AH: BIOS function read sectors from drive
;	mov		al,		14				;AL		Sectors To Read Count
	mov		ax,		0x020E
;	xor		ch,		ch				;CH		Cylinder
;	mov		cl,		0x02			;CL		Sector
;	xor		dh,		dh				;DH		Head
;	mov		dl,		DRIVE_NUMBER	;DL		Drive
	mov		bx,		ds				;ES:BX	Buffer Address Pointer
	mov		es,		bx
	mov		bx,		DISK_BUFFER
									;Results CF Set On Error, Clear If No Error
read_root_dir:
	stc				;a few BIOSes do not set properly on error
	int		0x13

	jnc		search_dir			;if read went OK, skip ahead
	call	reset_floppy		;reset floppy controller and try again
	jnc		read_root_dir		;floppy reset OK?

	jmp		reboot			;fatal double error

search_dir:
	mov		ax,		ds			;root dir is now in [DISK_BUFFER]
	mov		es,		ax
	mov		ax,		DISK_BUFFER
	mov		di,		ax
next_root_entry:
	mov		si,		KERNEL_FILENAME
	mov		cx,		FAT12_FULLNAME_SIZE
	rep		cmpsb
	je		found_file_to_load

	add		ax,		DIR_ENTRY_SIZE ;to next entry

	mov		di,		ax
	cmp		ax,		ROOT_DIR_END
	jne		next_root_entry

	mov		si,		FILE_NOT_FOUND
	call	print_string
	jmp		reboot

found_file_to_load:			;fetch cluster and load FAT into RAM
	mov		bp,		word[es:di+0x0F]	;offset FAT12_FULLNAME_SIZE +0x0F=26,
																;1st cluster
read_fat:
	mov		ax,		1	;1st sector of 1st FAT
	call	l2hts

	;https://en.wikipedia.org/wiki/INT_13H
;	mov		ah,		0x02			;AH: BIOS function read sectors from drive
;	mov		al,		9				;AL		Sectors To Read Count
	mov		ax,		0x0209
									;CH		Cylinder
									;CL		Sector
									;DH		Head
									;DL		Drive
	mov		bx,		DISK_BUFFER		;ES:BX	Buffer Address Pointer
									;Results CF Set On Error, Clear If No Error
	stc
	int		0x13

	jnc		read_fat_ok			;if read went OK, skip ahead
	call	reset_floppy		;reset floppy controller and try again
	jnc		read_fat			;floppy reset OK?

fatal_disk_error:
	mov		si,		DISK_ERROR	;if not, print error message and reboot
	call	print_string
	jmp		reboot				;fatal double error

read_fat_ok:
	mov		ax,		KERNEL_SEGMENT
	mov		es,		ax
	xor		di,		di		;ptr where to load data
;FAT cluster 0 = media descriptor = 0F0h
;FAT cluster 1 = filler cluster = 0FFh
;Cluster start = ((cluster number) - 2) * SectorsPerCluster + (start of user)
;              = (cluster number) + 31
;load FAT from disk
load_file_sector:
	lea		ax,		[bp + 31]
	call	l2hts

	mov		bx,		di

	mov		ax,		0x0201

	stc
	int		0x13

	jnc		calculate_next_cluster

	call	reset_floppy		;reset floppy and retry
	jmp		load_file_sector

	;FAT12 cluster value stored in 12 bits, so do bit mask 0x0FFF
calculate_next_cluster:
;FAT12 element 12 bit long. Need mul to 1.5
	mov		si,		bp
	mov		bx,		si
	shr		bx,		1
	mov		bp,		word[ds:si + bx + DISK_BUFFER]

	test	si,		1
	jz		even
odd:
	shr		bp,		4		;shift first 4 bits (they belong to another entry)
even:
	and		bp,		0x0FFF

next_cluster_cont:
	cmp		bp,		0x0FF8		;0xFF8 = end of file marker in FAT12
	jae		to_kernel

	add		di,		BYTES_PER_SECTOR
	jmp		load_file_sector

to_kernel:
	mov		dl,		byte[BOOT_DEVICE] ;provide to kernel the drive number

	jmp		KERNEL_SEGMENT:0x0000

; ------------------------------------------------------------------
; BOOTLOADER SUBROUTINES

reboot:
	xor		ax,		ax
	int		0x16		;wait for keystroke
	xor		ax,		ax
	int		0x19		;reboot the system


print_string:
;in: si = string ptr
	pusha

	mov		ah,		0x0E ;print char
.repeat:
	lodsb
	test	al,		al
	je		.done
	int		0x10 ;tty
	jmp short .repeat

.done:
	popa
	ret


reset_floppy:
;in: [bootdev] = boot device;
;out: carry set on error
	push	ax
	push	dx
	xor		ax,		ax
	mov		dl,		byte[BOOT_DEVICE]
	stc
	int		0x13
	pop		dx
	pop		ax
	ret


l2hts:
;in:  logical sector in AX
;out: correct registers for int 0x13

;calculate head, track and sector settings for int 0x13
	push	ax

	xor		dx,		dx
	div		word[SectorsPerTrack]
	inc		dl
	mov		cl,		dl	;sectors belong in cL for int 0x13
	pop		ax

	xor		dx,		dx
	div		word[SectorsPerTrack] ;SECTORS_PER_TRACK = 18
;	xor		dx,		dx
;	div		word[Sides] ;SIDES_AND_HEADS = 2
;	mov		dh,		dl	;head/side
;	mov		ch,		al	;track
	mov		dh,		al
	and		dh,		0x01
	mov		ch,		al
	shr		ch,		1

	xor		dl,		dl

	ret

BOOT_DEVICE db 0

	times 510-($-$$) db 0	;pad remainder of boot sector with zeros
	dw	0xAA55				;boot signature

DISK_BUFFER:
