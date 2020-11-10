;https://www.eit.lth.se/fileadmin/eit/courses/eitn50/Literature/fat12_description.pdf
;http://read.pudn.com/downloads77/ebook/294884/FAT32%20Spec%20%28SDA%20Contribution%29.pdf

DISK_BUFFER	equ 0x6000
;==================================FAT12 ERRORS================================
FAT12_ENTRY_NOT_FOUND equ 0xFFFF
;==================================ROOT DIRECTORY==============================
;______________________________________________________________________________
;|  byte  |                          Description
;|--------|--------------------------------------------------------------------
FAT12_NAME_SIZE equ 8
;|  0..7  | Filename (but see notes below about the first byte in this field)
FAT12_EXT_SIZE  equ 3
;|  8..10 | Extension
FAT12_FULLNAME_SIZE equ FAT12_NAME_SIZE + FAT12_EXT_SIZE
;|   11   | Attributes (see details below) 
;| 12..13 | Reserved 
;| 14..15 | Creation Time
;| 16..17 | Creation Date 
;| 18..19 | Last Access Date
;| 20..21 | Ignore in FAT12  
;| 22..23 | Last Write Time  
;| 24..25 | Last Write Date 
;| 26..27 | First Logical Cluster 
;| 28..31 | File Size (in bytes)
;------------------------------------------------------------------------------
;if filename[0] = 0xE5 => directory entry free
;if filename[0] = 0x00 => directory entry free and all remaining directory
;entries in this directory are free

;Volume structure
;0 - reserved region (bpb, boot)
;1 - FAT, FAT copy
;2 - root directory
;3 - data (file & directory)

;========================FILE & DIRECTORY==Attributes==========================
FAT12_ATTR_READ_ONLY	equ 0x01
FAT12_ATTR_HIDDEN		equ 0x02
FAT12_ATTR_SYSTEM		equ 0x04
FAT12_ATTR_VOLUME_LABEL equ 0x08
FAT12_ATTR_SUBDIRECTORY	equ 0x10
FAT12_ATTR_ARCHIVE		equ 0x20
;FAT12_ATTR_UNUSED		equ 0x40
;FAT12_ATTR_UNUSED		equ 0x80
;==============================================================================

;=============================DISK CONSTANTS===================================
DISK_SIZE_BYTES equ 1474560
BYTES_PER_SECTOR equ 512
SECTORS_PER_CLUSTER equ 1
SECTORS_RESERVED_FOR_BOOT equ 1
NUM_OF_FATS equ 2
NUM_OF_ENTRIES_ROOT_DIR equ 224
DIR_ENTRY_SIZE equ 32 ;in bytes
ROOT_DIR_SIZE equ NUM_OF_ENTRIES_ROOT_DIR * DIR_ENTRY_SIZE
ROOT_DIR_END equ ROOT_DIR_SIZE + DISK_BUFFER
SECTORS_TO_ROOT_DIR equ (NUM_OF_ENTRIES_ROOT_DIR * DIR_ENTRY_SIZE) / \
													BYTES_PER_SECTOR ;14
NUM_OF_LOGIC_SECTORS equ DISK_SIZE_BYTES / BYTES_PER_SECTOR ;2880
TYPE_OF_DISK equ 0xF0 ;3.5-inch (90 mm) Double Sided, 80 tracks per side,
			 	  ;18 or 36 sectors per track (1440 KB, known as “1.44 MB”)
SECTORS_PER_FAT equ 9
SECTORS_PER_TRACK equ 18
SIDES_AND_HEADS equ 2
NUM_HIDDEN_SECTORS equ 0
NUM_LARGE_SECTORS equ 0
DRIVE_NUMBER equ 0 ;0 for floppy, 0x80 for hdd
SIGNATURE equ 0x29
VOLUME_ID equ 0 ;ignore that
START_OF_ROOT equ SECTORS_RESERVED_FOR_BOOT + \
                    (NUM_OF_FATS * SECTORS_PER_FAT) ;19
START_USER_DATA equ START_OF_ROOT + SECTORS_TO_ROOT_DIR ;33
;==============================================================================

;read root in DISK_BUFFER
fat12_read_root:
;in:
;out:
	push	es
	mov		ax,		START_OF_ROOT
	call	l2hts

	;https://en.wikipedia.org/wiki/INT_13H
;	mov		ah,		0x02			;AH: BIOS function read sectors from drive
;	mov		al,		14				;AL		Sectors To Read Count
	mov		ax,		0x020E
									;CH		Cylinder
									;CL		Sector
									;DH		Head
									;DL		Drive
	mov		bx,		DISK_BUFFER		;ES:BX	Buffer Address Pointer
	mov		es,		bx
	xor		bx,		bx
									;Results CF Set On Error, Clear If No Error
	stc				;a few BIOSes do not set properly on error
	int		0x13
	pop		es
	retn

fat12_find_entry:
;in:  ds:si - name of file
;out: if found:  ax = ptr on fat12 entry
;	  not found: ax = FAT12_ENTRY_NOT_FOUND
	push	es
	push	si
	call	fat12_read_root
	pop		bx
	mov		ax,		DISK_BUFFER
	mov		es,		ax
	
	xor		ax,		ax
	xor		di,		di
.next_entry:
	mov		si,		bx
	mov		cx,		FAT12_FULLNAME_SIZE 
	rep		cmpsb	;ds:si, es:di
	je		.entry_found

	add		ax,		DIR_ENTRY_SIZE ;to next entry
	mov		di,		ax

	cmp		ax,		ROOT_DIR_SIZE
	jne		.next_entry
	mov		ax,		FAT12_ENTRY_NOT_FOUND
.entry_found:
	pop		es
	retn

read_fat:
	push	es
	mov		ax,		DISK_BUFFER
	mov		es,		ax

	mov		ax,		0x0001	;1st sector of 1st FAT
	call	l2hts
;https://en.wikipedia.org/wiki/INT_13H
;	mov		ah,		0x02	;AH: BIOS function read sectors from drive
;	mov		al,		0x09	;AL: Sectors To Read Count
	mov		ax,		0x0209
	;CH		Cylinder
	;CL		Sector
	;DH		Head
	;DL		Drive
	xor		bx,		bx
	;Results CF Set On Error, Clear If No Error
	stc
	int		0x13

	pop		es
	retn

STRTR db "           "

fat12_load_entry:
;in:  DISK_BUFFER:ax = ptr on fat12 entry
;	  es:si = LOAD PTR
;out: 
	mov		word[ds:pointer],	si
	mov		bx,		ax
	mov		ax,		DISK_BUFFER
	mov		gs,		ax
	mov		ax,		word[gs:bx+26]	;1st cluster (26st byte from
												 ;start of entry)
	mov		word[ds:cluster],	ax
	pusha
	call	read_fat
	popa
;FAT cluster 0 = media descriptor = 0F0h
;FAT cluster 1 = filler cluster = 0FFh
;Cluster start = ((cluster number) - 2) * SectorsPerCluster + START_USER_DATA
;              = (cluster number) + 31
;load FAT from disk
.load_file_sector:
	mov		ax,		word[ds:cluster]
	add		ax,		31
	call	l2hts
	mov		bx,		word[ds:pointer]
	mov		ax,		0x0201
	stc
	int		0x13

	jnc		.calculate_next_cluster

	call	reset_floppy		;reset floppy and retry
	jmp		.load_file_sector
.calculate_next_cluster:
;FAT12 element 12 bit long. Need mul to 1.5
	mov		si,		word[ds:cluster]
	mov		cx,		si
	and		cx,		1		;odd or even
	mov		bx,		si
	shr		bx,		1
	add		si,		bx
	mov		ax,		word[gs:si]

	;pusha
	;push	es
	;mov		bx,		VGA_BUFFER
	;mov		es,		bx
	;mov		si,		STRTR
	;mov		bx,		SYSCALL_UINT_TO_ASCII
	;int		0x20
	;mov		bx,		SYSCALL_TTY_PRINT_ASCII
	;int		0x20
;	mov		bx,		SYSCALL_TTY_PUTCHAR_ASCII
;	mov		al,		' '
;	int		0x20
;	pop		es
;	popa

	jcxz	.even
.odd:
	shr		ax,		4		;shift first 4 bits (they belong to another entry)
.even:
	and		ax,		0x0FFF
.next_cluster_cont:
	mov		word[ds:cluster],	ax	;store cluster

	cmp		ax,		0x0FF8		;0xFF8..0xFFF = end of file marker in FAT12
	jae		.exit

	add		word[ds:pointer],	BYTES_PER_SECTOR
	jmp		.load_file_sector
.exit:
	retn

reset_floppy:
;in: [bootdev] = boot device;
;out: carry set on error
	push	ax
	push	dx
	xor		ax,		ax
	xor		dx,		dx
	stc
	int		0x13
	pop		dx
	pop		ax
	retn

l2hts:
;in:  logical sector in AX
;out: correct registers for int 0x13

;calculate head, track and sector settings for int 0x13
	push	si
	push	ax

	xor		dx,		dx
	mov		si,		SECTORS_PER_TRACK
    div     si
	inc		dl
	mov		cl,		dl	;sectors belong in cL for int 0x13
	pop		ax

	xor     dx,     dx
    div     si
;   xor     dx,     dx
;   div     word[Sides] ;SIDES_AND_HEADS = 2
;   mov     dh,     dl  ;head/side
;   mov     ch,     al  ;track
    mov     dh,     al
    and     dh,     0x01
    mov     ch,     al
    shr     ch,     1

	xor		dl,		dl

	pop		si
	retn

cluster			dw 0
pointer			dw 0
