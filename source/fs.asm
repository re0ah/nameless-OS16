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

fat12_read_root:
;read fat12 root in DISK_BUFFER
;in:
;out: ah = return code BIOS int
;	  al = actual sectors read count
;	  bx = 0
;	  dx = ???
;	  ??? I don't know what's registers change read BIOS call
	push	es
;logic sector to physical
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
	int		0x13
	pop		es
	retn

fat12_file_size:
;in:  ds:si - name of file
;out: if found:  dx:ax = file size (dx - high, ax - low)
;	  not found: ax = FAT12_ENTRY_NOT_FOUND
	call	fat12_find_entry
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je		.not_found
	jmp		fat12_file_entry_size
.not_found:
	retn

fat12_file_entry_size:
;in:  DISK_BUFFER:ax = ptr on fat12 entry
;out: if found:  dx:ax = file size (dx - high, ax - low)
;	  not found: ax = FAT12_ENTRY_NOT_FOUND
	push	fs
	mov		dx,		DISK_BUFFER
	mov		fs,		dx
	mov		bx,		ax
	mov		ax,		word[fs:bx + 28]
	mov		dx,		word[fs:bx + 30]
	pop		fs
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
	push	es
	call	fat12_read_root
	mov		ax,		DISK_BUFFER
	mov		es,		ax
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

read_fat:
;in:  ds:si - name of file
;out: ah = return code BIOS int
;	  al = actual sectors read count
;	  bx = ???
;	  dx = ???
;	  ??? I don't know what's registers change read BIOS call
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
;	stc
	int		0x13

	pop		es
	retn

fat12_load_entry:
;in:  DISK_BUFFER:ax = ptr on fat12 entry
;	  es:si = LOAD PTR
;out: ax = bp + 31
;	  bx = si / 2
;	  cx = ?
;	  dx = dl = 0, dh = ?
;	  si = pos fat12 element
;	  di = where to load data
;	  bp = file marker of fat element
	mov		di,		si ;store ptr where to load data
	mov		bx,		ax ;fat12 entry ptr
	mov		ax,		DISK_BUFFER
	mov		gs,		ax
	mov		bp,		word[gs:bx + 26] ;1st cluster (26st byte from
										;start of entry)
									 ;store cluster number
	pusha
	call	read_fat
	popa
;FAT cluster 0 = media descriptor = 0F0h
;FAT cluster 1 = filler cluster = 0FFh
;Cluster start = ((cluster number) - 2) * SectorsPerCluster + START_USER_DATA
;              = (cluster number) + 31
;load FAT from disk
.load_file_sector:
	lea		ax,		[bp + 31]
	call	l2hts
	mov		bx,		di
	mov		ax,		0x0201
	stc
	int		0x13

	jnc		.calculate_next_cluster

	call	reset_floppy		;reset floppy and retry
	jmp		.load_file_sector
.calculate_next_cluster:
;FAT12 element 12 bit long. Need mul to 1.5
	mov		si,		bp
	mov		bx,		si
	shr		bx,		1
	mov		bp,		word[gs:si + bx]

	test	si,		1
	jz		.even
.odd:
	shr		bp,		4		;shift first 4 bits (they belong to another entry)
.even:
	and		bp,		0x0FFF
.next_cluster_cont:
	cmp		bp,		0x0FF8		;0xFF8..0xFFF = end of file marker in FAT12
	jae		.exit

	add		di,		BYTES_PER_SECTOR
	jmp		.load_file_sector
.exit:
	retn

fat12_rename_file:
;in:  si = filename
;out: di = new filename
	push	es
	push	di
	push	si
	call	fat12_find_entry
	pop		si
	mov		di,		DISK_BUFFER
	mov		es,		di
	mov		di,		ax
	pop		si
	mov		cx,		11
	rep		movsb

	mov		ax,		START_OF_ROOT
	call	l2hts

	xor		bx,		bx
	mov		ax,		0x030E	;write 14 entries
	int		0x13
	pop		es
	retn

fat12_create_entry:
;in:  si = filename
;out: 
	call	fat12_read_root
	push	es
	mov		ax,		DISK_BUFFER
	mov		es,		ax
	xor		di,		di
	mov		cx,		224
.next_entry:
	mov		al,		byte[es:di]
	test	al,		al
	je		.found_free_entry
	cmp		al,		0xE5
	je		.found_free_entry
	add		di,		32
	loop	.next_entry
	pop		es
	retn
.found_free_entry:
	mov		cx,		11
	rep		movsb		;cp fname

	mov		al,		0
	mov		cx,		21
	rep		stosb

	sub		di,		32
	call	fat12_set_time_now_entry
	call	fat12_set_date_now_entry

	mov		ax,		START_OF_ROOT
	call	l2hts

	mov		bx,		DISK_BUFFER		;ES:BX	Buffer Address Pointer
	mov		es,		bx
	xor		bx,		bx

	mov		ax,		0x030E	;write 14 entries

	int		0x13
	pop		es
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
	call	rtc_get_hour_bin
	shl		ax,		11
	and		ax,		0xF800
	mov		bx,		ax
	call	rtc_get_min_bin
	shl		ax,		5
	and		ax,		0x07E0
	mov		cx,		ax
	call	rtc_get_sec_bin
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
	call	rtc_get_century_bin
	mov		bx,		ax
	call	rtc_get_year_bin
	add		bx,		ax
	shl		bx,		9
	and		bx,		0xFE00
	call	rtc_get_month_bin
	shl		ax,		5
	and		ax,		0x01E0
	mov		cx,		ax
	call	rtc_get_day_bin
	and		ax,		0x001F
	or		ax,		bx
	or		ax,		cx

	mov		word[es:di + 16],	ax
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

os_write_file:
;in:  si = filename
;	  bx = data location
;	  cx = data size
;out: 
	pusha

	mov		word[.filesize],	cx
	mov		word[.location],	bx
	mov		word[.filename],	ax

	; First, zero out the .free_clusters list from any previous execution
	pusha

;es=ds
	push	es	;store es
	push	ds
	pop		es
	mov		di,		.free_clusters
	xor		ax,		ax
	mov		cx,		128
	rep		stosw	;word[es:di] = ax
	pop		es	;load es

	popa
	; Next, we need to calculate now many 512 byte clusters are required
	mov		ax,		cx
	mov		dx,		0
	mov		bx,		512		; Divide file size by 512 to get clusters needed
	div		bx
	cmp		dx,		0
	jg		.add_a_bit			; If there's a remainder, we need another cluster
	jmp		.carry_on

.add_a_bit:
	add		ax,		1
.carry_on:
	mov		word[.clusters_needed], ax

	mov		ax,		word[.filename]	; Get filename back

	;call	os_create_file		; Create empty root dir entry for this file
	jc		near .failure		; If we can't write to the media, jump out

	mov		word bx, [.filesize]
	cmp		bx, 0
	je		near .finished

	;call	disk_read_fat		; Get FAT copy into RAM
	;mov		si, disk_buffer + 3		; And point SI at it (skipping first two clusters)

	mov		bx,		2			; Current cluster counter
	mov		cx,		word[.clusters_needed]
	mov		dx,		0			; Offset in .free_clusters list

.find_free_cluster:
	lodsw				; Get a word
	and ax, 0FFFh			; Mask out for even
	jz .found_free_even		; Free entry?

.more_odd:
	inc bx				; If not, bump our counter
	dec si				; 'lodsw' moved on two chars; we only want to move on one

	lodsw				; Get word
	shr ax, 4			; Shift for odd
	or ax, ax			; Free entry?
	jz .found_free_odd

.more_even:
	inc bx				; If not, keep going
	jmp .find_free_cluster


.found_free_even:
	push si
	mov si, .free_clusters		; Store cluster
	add si, dx
	mov word [si], bx
	pop si

	dec cx				; Got all the clusters we need?
	cmp cx, 0
	je .finished_list

	inc dx				; Next word in our list
	inc dx
	jmp .more_odd

.found_free_odd:
	push si
	mov si, .free_clusters		; Store cluster
	add si, dx
	mov word [si], bx
	pop si

	dec cx
	cmp cx, 0
	je .finished_list

	inc dx				; Next word in our list
	inc dx
	jmp .more_even



.finished_list:

	; Now the .free_clusters table contains a series of numbers (words)
	; that correspond to free clusters on the disk; the next job is to
	; create a cluster chain in the FAT for our file

	mov cx, 0			; .free_clusters offset counter
	mov word [.count], 1		; General cluster counter

.chain_loop:
	mov word ax, [.count]		; Is this the last cluster?
	cmp word ax, [.clusters_needed]
	je .last_cluster

	mov di, .free_clusters

	add di, cx
	mov word bx, [di]		; Get cluster

	mov ax, bx			; Find out if it's an odd or even cluster
	mov dx, 0
	mov bx, 3
	mul bx
	mov bx, 2
	div bx				; DX = [.cluster] mod 2
	;mov si, disk_buffer
	add si, ax			; AX = word in FAT for the 12 bit entry
	mov ax, word [ds:si]

	or dx, dx			; If DX = 0, [.cluster] = even; if DX = 1 then odd
	jz .even

.odd:
	and ax, 000Fh			; Zero out bits we want to use
	mov di, .free_clusters
	add di, cx			; Get offset in .free_clusters
	mov word bx, [di+2]		; Get number of NEXT cluster
	shl bx, 4			; And convert it into right format for FAT
	add ax, bx

	mov word [ds:si], ax		; Store cluster data back in FAT copy in RAM

	inc word [.count]
	inc cx				; Move on a word in .free_clusters
	inc cx

	jmp .chain_loop

.even:
	and ax, 0F000h			; Zero out bits we want to use
	mov di, .free_clusters
	add di, cx			; Get offset in .free_clusters
	mov word bx, [di+2]		; Get number of NEXT free cluster

	add ax, bx

	mov word [ds:si], ax		; Store cluster data back in FAT copy in RAM

	inc word [.count]
	inc cx				; Move on a word in .free_clusters
	inc cx

	jmp .chain_loop



.last_cluster:
	mov di, .free_clusters
	add di, cx
	mov word bx, [di]		; Get cluster

	mov ax, bx

	mov dx, 0
	mov bx, 3
	mul bx
	mov bx, 2
	div bx				; DX = [.cluster] mod 2
	;mov si, disk_buffer
	add si, ax			; AX = word in FAT for the 12 bit entry
	mov ax, word [ds:si]

	or dx, dx			; If DX = 0, [.cluster] = even; if DX = 1 then odd
	jz .even_last

.odd_last:
	and ax, 000Fh			; Set relevant parts to FF8h (last cluster in file)
	add ax, 0FF80h
	jmp .finito

.even_last:
	and ax, 0F000h			; Same as above, but for an even cluster
	add ax, 0FF8h


.finito:
	mov word [ds:si], ax

	;call disk_write_fat		; Save our FAT back to disk


	; Now it's time to save the sectors to disk!

	mov cx, 0

.save_loop:
	mov di, .free_clusters
	add di, cx
	mov word ax, [di]

	cmp ax, 0
	je near .write_root_entry

	pusha

	add ax, 31

	;call disk_convert_l2hts

	mov word bx, [.location]

	mov ah, 3
	mov al, 1
	stc
	int 13h

	popa

	add word [.location], 512
	inc cx
	inc cx
	jmp .save_loop


.write_root_entry:

	; Now it's time to head back to the root directory, find our
	; entry and update it with the cluster in use and file size

	;call disk_read_root_dir

	mov word ax, [.filename]
	;call disk_get_root_entry

	mov word ax, [.free_clusters]	; Get first free cluster

	mov word [di+26], ax		; Save cluster location into root dir entry

	mov word cx, [.filesize]
	mov word [di+28], cx

	mov byte [di+30], 0		; File size
	mov byte [di+31], 0

	;call disk_write_root_dir

.finished:
	popa
	clc
	ret

.failure:
	popa
	stc				; Couldn't write!
	ret


	.filesize	dw 0
	.cluster	dw 0
	.count		dw 0
	.location	dw 0

	.clusters_needed	dw 0

	.filename	dw 0

	.free_clusters	times 128 dw 0


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
