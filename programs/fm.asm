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
bits 16

%include "../source/syscall.inc"

VGA_BUFFER		equ 0xB800
VGA_WIDTH       equ 80
VGA_HEIGHT      equ 25
VGA_CHAR_SIZE   equ 2 ;bytes
VGA_ROW_SIZE    equ VGA_CHAR_SIZE * VGA_WIDTH
VGA_PAGE_SIZE	equ	VGA_ROW_SIZE * VGA_HEIGHT
VGA_PAGE_NUM_CHARS equ VGA_WIDTH * VGA_HEIGHT ;1000 chars

DISK_BUFFER equ 0x6000
WINDOWS_MARKER equ 0x0F
DIR_ENTRY_SIZE equ 32 ;in bytes
FAT12_ENTRY_NOT_FOUND equ 0xFFFF

fm:
	mov		bx,		SYSCALL_VGA_CURSOR_DISABLE
	int		0x20

	xor		di,		di
	mov		ah,		0x03
	mov		al,		' '
	mov		cx,		VGA_PAGE_NUM_CHARS
	rep		stosw
	call	draw_wall
	call	output_dir
	call	choose_file

.wait_keyboard_data:
	hlt
	mov		bx,		SYSCALL_GET_KEYBOARD_DATA
	int		0x20
	test	al,		al
	je		.wait_keyboard_data
	cmp		al,		0x01	;ESC
	je		.exit
	cmp		al,		0xE9
	jne		.not_up_arrow
	mov		di,		word[item_now]
	test	di,		di
	je		.wait_keyboard_data
	call	unchoose_file
	dec		word[item_now]
	call	choose_file
	jmp		.wait_keyboard_data
.not_up_arrow:
	cmp		al,		0xEB
	jne		.not_down_arrow
	mov		di,		word[item_now]
	cmp		di,		word[item_num]
	je		.wait_keyboard_data
	call	unchoose_file
	inc		word[item_now]
	call	choose_file
	jmp		.wait_keyboard_data
.not_down_arrow:
	cmp		al,		0x1C
	jne		.if_not_enter
	call	enter
.if_not_enter:
	jmp		.wait_keyboard_data
.exit:
	mov		bx,		SYSCALL_VGA_CLEAR_SCREEN
	int		0x20
	mov		bx,		SYSCALL_VGA_CURSOR_ENABLE
	int		0x20

	xor		ax,		ax	;exit status
	retf

enter:
	mov		si,		word[item_now]
	shl		si,		5
	mov		di,		si
	shl		di,		2
	add		si,		di
	add		si,		326

	mov		di,		FAT12_FNAME
	mov		cx,		8
.lp_fname:
	mov		ax,		word[es:si]
	mov		byte[ds:di], al
	add		si,		2
	inc		di
	loop	.lp_fname

	add		si,		2
	mov		cx,		3
.lp_ext:
	mov		ax,		word[es:si]
	mov		byte[ds:di], al
	add		si,		2
	inc		di
	loop	.lp_ext

	mov		si,		FAT12_FNAME
	mov		cx,		8
	mov		bx,		SYSCALL_EXECVE
	int		0x20
	cmp		ax,		FAT12_ENTRY_NOT_FOUND
	je		.not_found
.not_found:
	retn

choose_file:
	mov		di,		word[item_now]
	shl		di,		5
	mov		si,		di
	shl		si,		2
	add		di,		si
	add		di,		326

	mov		cx,		12
.lp:
	mov		ax,		word[es:di]
	mov		ah,		0x74
	stosw
	loop	.lp
	retn

unchoose_file:
	mov		di,		word[item_now]
	shl		di,		5
	mov		si,		di
	shl		si,		2
	add		di,		si
	add		di,		326

	mov		cx,		12
.lp:
	mov		ax,		word[es:di]
	mov		ah,		0x07
	stosw
	loop	.lp
	retn

output_dir:
	mov		bx,		SYSCALL_FAT12_READ_ROOT
	int		0x20
	push	ds
	mov		ax,		DISK_BUFFER
	mov		ds,		ax
	
	xor		cx,		cx		;num of files in directory
	mov		ah,		0x07
	xor		bx,		bx
.lp:
	mov		di,		cx
	shl		di,		5
	mov		si,		di
	shl		si,		2
	add		di,		si
	add		di,		326
	mov		si,		bx
	mov		al,		byte[ds:si + 11] ;attributes
	cmp		al,		WINDOWS_MARKER
	je		.next
	xor		bp,		bp
	inc		cx
.cp_fname:
	lodsb
	inc		bp
	stosw
	cmp		bp,		8
	jne		.cp_fname
	mov		al,		' '
	stosw
	xor		bp,		bp
.cp_ext:
	lodsb
	inc		bp
	stosw
	cmp		bp,		3
	jne		.cp_ext
.end_ext:
	add		di,		160
.next:
	add		bx,		DIR_ENTRY_SIZE	;to next entry
;check last file in directory or not
	mov		al,		byte[ds:bx]
	test	al,		al
	jne		.lp
	pop		ds

	dec		cx
	mov		word[item_num],	cx
	retn

draw_wall:
;in:
;out: ax = 0x7720
;	  cx = 0
;	  di = 0
;draw from left-top point box like
;->->->->---
;|         |
;/\        \/
;|         |
;--<-<-<-<-|
;draw top side wall
	mov		ax,		0x7720	;bg=gray, fg=gray, char=' '
	mov		cx,		VGA_WIDTH
	xor		di,		di
	rep		stosw	;ax -> es:di
;draw right side wall
	sub		di,		VGA_CHAR_SIZE
.lp_right:
	add		di,		VGA_WIDTH * VGA_CHAR_SIZE
	mov		word[es:di],	ax
	cmp		di,		VGA_PAGE_SIZE - VGA_CHAR_SIZE
	jne		.lp_right
;draw bottom side wall
.lp_left:
	sub		di,		VGA_CHAR_SIZE
	mov		word[es:di],	ax
	cmp		di,		(VGA_HEIGHT - 1) * VGA_ROW_SIZE
	jne		.lp_left
;draw left side wall
.lp_up:
	sub		di,		VGA_CHAR_SIZE * VGA_WIDTH
	mov		word[es:di],	ax
	test	di,		di
	jne		.lp_up

	retn

item_now dw 0
item_num dw 0
FAT12_FNAME db "LS      BIN"
