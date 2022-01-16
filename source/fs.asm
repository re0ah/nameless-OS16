;This is free and unencumbered software released into the public domain.

;Anyone is free to copy, modify, publish, use, compile, sell, or
;distribute this software, either in source code form or as a compiled
;binary, for any purpose, commercial or non-commercial, and by any
;means.

;In jurisdictions that recognize copyright laws, the author or authors
;of this software dedicate any and all copyright interest in the
;software to the public domain. We make this dedication for the benefit
;of the public at large and to the detriment of our heirs and
;successors. We intend this dedication to be an overt act of
;relinquishment in perpetuity of all present and future rights to this
;software under copyright law.

;THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
;IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
;OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
;ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
;OTHER DEALINGS IN THE SOFTWARE.

;For more information, please refer to <http://unlicense.org/>

;https://github.com/mig-hub/mikeOS/blob/master/source/features/disk.asm

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

;DOS 4.0 EBPB, disk description table
;MAIN_EBPB:
;	.OEM_label			 times 9 db ' '
;	.bytes_per_sector	 dw 0
;	.sectors_per_cluster db 0
;	.reserved_for_boot	 dw 0
;	.number_of_fats		 db 0
;	.root_dir_entries	 dw 0
;	.logical_sectors	 dw 0
;	.medium_byte		 db 0
;	.sectors_per_fat	 dw 0
;	.sectors_per_track	 dw 0
;	.sides				 dw 0
;	.hidden_sectors		 dd 0
;	.large_sectors		 dd 0
;	.drive_no			 db 0
;	.reserved			 db 0
;	.signature			 db 0
;	.volume_id			 dd 0
;	.volume_label		 times 11 db ' '
;	.file_system		 db "FAT12   "
;MAIN_EBPB_SIZE equ $ - MAIN_EBPB

;fs_init:
;get EBPB from bootloader and save disk description table
;	push	es
;	xor		ax,		ax	;read first sector - bootloader contain info about disk
;	call	l2hts
;	mov		ax,		0x0201			;AH: BIOS function read sectors from drive
									;AL		Sectors To Read Count
									;CH		Cylinder
									;CL		Sector
									;DH		Head
;									;DL		Drive
;	push	DISK_BUFFER				;ES:BX	Buffer Address Pointer
;	pop		es
;	xor		bx,		bx
;									;Results CF Set On Error, Clear If No Error
;	int		0x13	;BIOS disk routines

;need save ebpb from disk
;	mov		si,		MAIN_EBPB
;	xor		di,		di
;	mov		cx,		MAIN_EBPB_SIZE
;	rep		movsb

;	pop		es
;	retn

fat12_read:
;in: ax = logic sector
;	 es:bx = place
;	 cl = how many clusters to read
	pusha
	push	cx

	call	l2hts

;	mov		ah,		0x02	;AH: BIOS function read sectors from drive
;	mov		al,		0x09	;AL: Sectors To Read Count
	pop		ax
	mov		ah,		0x02	;BIOS read
							;CH		Cylinder
							;CL		Sector
							;DH		Head
							;DL		Drive
	;Results CF Set On Error, Clear If No Error
;	stc
	int		0x13

	popa
	retn

fat12_read_root:
;read fat12 root in DISK_BUFFER
;in:
;out: ah = return code BIOS int
;	  al = actual sectors read count
;	  bx = 0
	mov		ax,		START_OF_ROOT
	xor		bx,		bx
	mov		cl,		0x02
	push	es
	push	DISK_BUFFER
	pop		es
	call	fat12_read
	pop		es
	retn

fat12_file_size:
;in:  ds:si - name of file
;out: if found:  dx:ax = file size (dx - high, ax - low)
;	  not found: ax = FAT12_ENTRY_NOT_FOUND
	call	fat12_find_entry
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	jne     fat12_file_entry_size
.not_found:
	retn

fat12_file_entry_size:
;in:  DISK_BUFFER:ax = ptr on fat12 entry
;out: if found:  dx:ax = file size (dx - high, ax - low)
;	  not found: ax = FAT12_ENTRY_NOT_FOUND
	push	fs
	push	DISK_BUFFER
	pop		fs
	mov		bx,		ax
	mov		ax,		word[fs:bx + 28]
	mov		dx,		word[fs:bx + 30]
	pop		fs
.end:
	retn

fat12_find_entry:
;in:  ds:si - name of file
;out: if found:  ax = ptr on fat12 entry
;				 di = ax + FAT12_FULLNAME_SIZE
;				 bx = si
;				 si = bx + FAT12_FULLNAME_SIZE
;	  not found: ax = FAT12_ENTRY_NOT_FOUND
;				 di = ROOT_DIR_SIZE
;				 bx = si
;				 si = bx + FAT12_FULLNAME_SIZE
	call	fat12_read_root
	push	es
	push	DISK_BUFFER
	pop		es
;on disk buffer root now, check all root before entry doesn't found
	mov		bx,		si 
	xor		ax,		ax ;entry counter
	xor		di,		di ;entry pointer for comparison
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

fat12_read_fat:
	mov		ax,		0x0001	;1st sector of 1st FAT
	xor		bx,		bx
	mov		cl,		0x09
	push	es
	push	DISK_BUFFER
	pop		es
	call	fat12_read
	pop		es
	retn

fat12_load_entry:
;in:  DISK_BUFFER:di = ptr on fat12 entry
;	  es:bx = LOAD PTR
;out: ax = bp + 31
;	  bx = si / 2
;	  cx = ?
;	  dx = dl = 0, dh = ?
;	  si = pos fat12 element
;	  di = where to load data
;	  bp = file marker of fat element
;	  fs = DISK_BUFFER
	push	DISK_BUFFER
	pop		fs
	mov		si,		word[fs:di + 26] ;1st cluster (26st byte from
										;start of entry)
									 ;store cluster number
	push	word[fs:di + 28]	;file size
	call	fat12_get_file_clusters_list
	mov		si,		fat12_write_file_free_clusters
.reading_file_data:
	lodsw
	test	ax,		ax
	je		.exit
	mov		cl,		1
	call	fat12_read
	add		bx,		512
	jmp		.reading_file_data
.exit:
	pop		cx	;file size
	retn

fat12_get_file_clusters_list:
;FAT cluster 0 = media descriptor = 0F0h
;FAT cluster 1 = filler cluster = 0FFh
;Cluster start = ((cluster number) - 2) * SectorsPerCluster + START_USER_DATA
;              = (cluster number) + 31
	pusha
	call	fat12_read_fat
	push	es
	push	KERNEL_SEGMENT
	pop		es
	mov		di,		fat12_write_file_free_clusters
.load_file_sector:
	lea		ax,		[si + 31]
	stosw
	push	di
	call	calculate_next_cluster
	pop		di
	jnae	.load_file_sector
.exit:
	mov		word[es:di],	0
	pop		es
	popa
	retn

calculate_next_cluster:
;FAT12 element 12 bit long. Need mul to 1.5
	mov		ax,		si
	mov		di,		ax
	shr		di,		1
	add		di,		ax
	mov		si,		word[fs:di]

	test	al,		1
	jz		.even
.odd:
	shr		si,		4		;shift first 4 bits (they belong to another entry)
.even:
	and		si,		0x0FFF
.next_cluster_cont:
	cmp		si,		0x0FF8		;0xFF8..0xFFF = end of file marker in FAT12
	retn

fat12_write_root:
;in: es = DISK_BUFFER, has changed root dir for save
	mov		ax,		START_OF_ROOT
	call	l2hts

	xor		bx,		bx
	mov		ax,		0x030E	;write 14 entries
	int		0x13
	retn

fat12_rename_file:
;in:  ds:si = filename
;out: ds:di = new filename
	push	es
	push	di
	push	si
	call	fat12_find_entry
	pop		si
	push	DISK_BUFFER
	pop		es
	mov		di,		ax
	pop		si
	mov		cx,		11
	rep		movsb

	call	fat12_write_root
	pop		es
	retn

fat12_find_free_entry:
	push	es
	push	DISK_BUFFER
	pop		es
	call	fat12_read_root
	xor		di,		di
.next_entry:
	mov		al,		byte[es:di]
	test	al,		al
	je		.found_free_entry
	cmp		al,		0xE5
	je		.found_free_entry
	add		di,		DIR_ENTRY_SIZE
	cmp		di,		DIR_ENTRY_SIZE * NUM_OF_ENTRIES_ROOT_DIR
	jne		.next_entry
;root is full
.found_free_entry:
	pop		es
	retn

fat12_create_entry:
;in:  si = filename
;	  ax = cluster location
;	  cx = filesize
;out: 
	push	es
	push	cx
	push	ax
	push	DISK_BUFFER
	pop		es

	call	fat12_find_free_entry
	cmp		di,		DIR_ENTRY_SIZE * NUM_OF_ENTRIES_ROOT_DIR
	jne		.found_free_entry

	pop		ax
	pop		cx
	pop		es
	retn
.found_free_entry:
	mov		cx,		11
	rep		movsb		;cp fname

	xor		al,		al
	mov		cx,		21
	rep		stosb

	sub		di,		DIR_ENTRY_SIZE
	pop		ax
	mov		word[es:di + 26],	ax	;cluster location
	pop		cx
	mov		word[es:di + 28],	cx	;filesize
	call	fat12_set_time_now_entry
	call	fat12_set_date_now_entry

	call	fat12_write_root
	pop		es
	retn

fat12_load_file:
;in: ds:si = name of file
;	 es:di = ptr to load
	push	di
	call	fat12_find_entry
	pop		bx
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je		.end
	mov		di,		ax
	call	fat12_load_entry
.end:
	retn

fat12_set_time_now_entry:
;in:  di = entry
;out:
;structure of fat12 time
;|-----|-------------------|
;|bits |    description    |
;|-----|-------------------|
;|15-11|    Hours (0-23)   |
;|10-5 |   Minutes (0-59)  |
;| 4-0 |  Seconds/2 (0-29) |
;|-----|-------------------|
	mov		al,		RTC_HOUR
	call	rtc_get_data_bin
	shl		ax,		11
	and		ax,		0xF800
	mov		bx,		ax

	mov		al,		RTC_MINUTE
	call	rtc_get_data_bin
	shl		ax,		5
	and		ax,		0x07E0
	mov		cx,		ax

	mov		al,		RTC_SECOND
	call	rtc_get_data_bin
	shr		ax,		1
	and		ax,		0x001F
	or		ax,		bx
	or		ax,		cx

	mov		word[es:di + 14],	ax
	retn

fat12_set_date_now_entry:
;in:  di = entry
;out: 
;structure of fat12 time
;|------|-------------------|
;| bits |    description    |
;|------|-------------------|
;| 15-9 |    Years (0-127)  |
;|  8-5 |    Month (1-12)   |
;|  4-0 |    Days  (1-31)   |
;|------|-------------------|
	mov		al,		RTC_CENTURY
	call	rtc_get_data_bin
	mov		bx,		ax

	mov		al,		RTC_YEAR
	call	rtc_get_data_bin
	add		bx,		ax
	shl		bx,		9
	and		bx,		0xFE00

	mov		al,		RTC_MONTH
	call	rtc_get_data_bin
	shl		ax,		5
	and		ax,		0x01E0
	mov		cx,		ax

	mov		al,		RTC_DAY
	call	rtc_get_data_bin
	and		ax,		0x001F
	or		ax,		bx
	or		ax,		cx

	mov		word[es:di + 16],	ax
	retn

fat12_find_free_cluster:
	mov		di,		3
	mov		bx,		2
	mov		cx,		word[fat12_write_file_clusters_needed]
	mov		si,		fat12_write_file_free_clusters
.next_cluster:
	mov		ax,		word[es:di]
	add		di,		2
	and		ax,		0x0FFF			; Mask out for even
	jnz		.more_odd ; Free entry?
.found_free_even:
	call	.save_cluster
.more_odd:
	inc		bx				; If not, bump our counter

	mov		ax,		word[es:di - 1]
	inc		di
	shr		ax,		4			; Shift for odd
	test	ax,		ax
	jnz		.more_even
.found_free_odd:
	call	.save_cluster
.more_even:
	inc		bx				; If not, keep going
	jmp		.next_cluster

.save_cluster: ;this is function!
	mov		word[si],	bx
	add		si,		2

	dec		cx
	jcxz	.finished_list_free
	retn
.finished_list_free:
	pop		ax		;free return address
	retn

fat12_fill_fat12_table:
	mov		word[fat12_write_file_count],	1		; General cluster counter
	mov		si,		fat12_write_file_free_clusters			; .free_clusters ptr
.next_cluster:
	lodsw
	; Find out if it's an odd or even cluster
	mov		di,		ax
	shr		di,		1
	add		di,		ax

	mov		cx,		word[es:di]

	mov		bx,		word[fat12_write_file_count]		; Is this the last cluster?
	cmp		bx,		word[fat12_write_file_clusters_needed]
	je		.last_cluster

	mov		bx, 	word[si]		; Get number of NEXT cluster
	test	al,		1
	jz		.even
.odd:
	and		cx,		0x000F			; Zero out bits we want to use
	shl		bx,		4			; And convert it into right format for FAT
	jmp		.store_cluster_in_fat
.even:
	and     cx,     0xF000          ; Zero out bits we want to use
.store_cluster_in_fat:
	add     cx,     bx
	mov     word[es:di], cx     ; Store cluster data back in FAT copy in RA    M
	inc     word[fat12_write_file_count]
	jmp     .next_cluster

.last_cluster:
	or		dx,		dx
	test	dx,		1
	jz		.even_last
.odd_last:
	and		cx,		0x000F			; Set relevant parts to FF8h (last cluster in file)
	add		cx,		0xFF80
	mov		word[es:di],	cx
	retn
.even_last:
	and		cx,		0xF000			; Same as above, but for an even cluster
	add		cx,		0x0FF8
	mov		word[es:di],	cx
	retn

fat12_write_fat:
	pusha
	mov		ax,		1			; FAT starts at logical sector 1 (after boot sector)
	call	l2hts

	xor		bx,		bx
	mov		ax,		0x0309	;write 9 sectors to first FAT
	int		0x13		; Write sectors
	popa				; And restore from start of system call
	retn

fat12_save_data_to_disk:
	mov		bx,		word[fat12_write_file_location]
	mov		si,		fat12_write_file_free_clusters
.next_cluster:
	lodsw

	test	ax,		ax
	jne		.continue
	retn
.continue:
	pusha
	add		ax,		31

	call	l2hts

	push	es
	push	fs
	pop		es
	mov		ax,		0x0301	;write 1 sector
	int		0x13
	pop		es
	popa

	add		bx,		512
	jmp		.next_cluster

fat12_calc_clusters_needed:
	xor		dx,		dx
	div		word[sector_size]
	test	dx,		dx
	je		.aliquot
.not_aliquot:
	inc		ax
.aliquot:
	retn

fat12_create_file:
;in:  ds:si = filename
;	  fs:bx = data location
;	  ds:cx = data size
;out:
	test	cx,		cx
	je		.exit
	mov		word[fat12_write_file_filename],	si
	mov		word[fat12_write_file_location],	bx
	mov		word[fat12_write_file_size],	cx

	call	fat12_find_entry
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	jne		.exit
.without_saving_data:
	push	es
;es = ds
	push	ds
	pop		es
;zeroing array
	mov		di,		fat12_write_file_free_clusters
	xor		ax,		ax
	mov		cx,		128
	rep		stosw	;word[es:di] = ax
;es = DISK_BUFFER
	push	DISK_BUFFER
	pop		es

	mov		ax,		word[fat12_write_file_size]
	call	fat12_calc_clusters_needed
	mov		word[fat12_write_file_clusters_needed], ax

	call	fat12_read_fat

	call	fat12_find_free_cluster

	call	fat12_fill_fat12_table

	call	fat12_write_fat
	pop		es
	call	fat12_save_data_to_disk

	mov     si,     word[fat12_write_file_filename]
	mov     ax,     word[fat12_write_file_free_clusters]    ;get first free cluster
	mov     cx,     word[fat12_write_file_size]
	jmp		fat12_create_entry

.exit:
	retn

fat12_write_file:
;in: ds:si = filename
;	 fs:bx = data location
;	 ds:cx = data size
	mov		word[fat12_write_file_filename],	si
	mov		word[fat12_write_file_location],	bx
	mov		word[fat12_write_file_size],	cx

	call	fat12_find_entry
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je      fat12_create_file.without_saving_data
	push	es
;es = ds
	push	ds
	pop		es
;zeroing array
	mov		di,		fat12_write_file_free_clusters
	xor		ax,		ax
	mov		cx,		128
	rep		stosw	;word[es:di] = ax
;es = DISK_BUFFER
	push	DISK_BUFFER
	pop		es

	mov		ax,		word[fat12_write_file_size]
	call	fat12_calc_clusters_needed
	mov		word[fat12_write_file_clusters_needed], ax

	call	fat12_read_fat

	call	fat12_find_free_cluster

	call	fat12_fill_fat12_table

	call	fat12_write_fat
	pop		es
	call	fat12_save_data_to_disk

.exit:
	retn

fat12_copy_file:
;in:  ds:si = copy file filename
;	  ds:di = new file filename
;out:
	mov		word[fat12_write_file_filename],	di

	push	fs
	push	es
	push	DISK_BUFFER + 0x8000 ;half of disk_buffer, only 32 KiB...
	pop		es
	xor		di,		di
	call	fat12_load_file
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je		.exit
	xor		bx,		bx
	mov		si,		word[fat12_write_file_filename]
	pop		es
	push	DISK_BUFFER + 0x8000
	pop		fs
	call	fat12_create_file
.exit:
	pop		fs
	retn

fat12_remove_file:
;in: ds:si = name of file
	call	fat12_find_entry
	mov		di,		ax
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	jne		fat12_remove_entry
.end:
	retn

fat12_remove_entry:
;in:  DISK_BUFFER:di = ptr on fat12 entry
;	  es:bx = LOAD PTR
;out: ax = bp + 31
;	  bx = si / 2
;	  cx = ?
;	  dx = dl = 0, dh = ?
;	  si = pos fat12 element
;	  di = where to load data
;	  bp = file marker of fat element
;	  gs = DISK_BUFFER
	push	fs
	push	es
	push	DISK_BUFFER
	pop		es
	push	es
	pop		fs
	mov		si,		word[es:di + 26] ;1st cluster (26st byte from
										;start of entry)
									 ;store cluster number
;clear entry data from root directory
;	xor		ax,		ax
;	mov		cx,		32
;	rep		stosw
;move entres data for clear entry data
	pusha
	push	ds
	push	es
	pop		ds
	lea		si,		[di + 32]
	mov		cx,		2048
	rep		movsw
	pop		ds
	call	fat12_write_root
	popa

	pusha
	call	fat12_read_fat
	popa
;FAT cluster 0 = media descriptor = 0F0h
;FAT cluster 1 = filler cluster = 0FFh
;Cluster start = ((cluster number) - 2) * SectorsPerCluster + START_USER_DATA
;              = (cluster number) + 31
;load FAT from disk
.zeroing_file_sector:
	lea		ax,		[si + 31]
	call	calculate_next_cluster
	mov		word[es:di],	0
	jae		.exit
	jmp		.zeroing_file_sector
.exit:
	xor		bx,		bx
	call	fat12_write_fat
	pop		es
	pop		fs
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

