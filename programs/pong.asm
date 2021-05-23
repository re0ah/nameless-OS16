;rewriting code from https://github.com/YotamShvartsun/best-pong-ever

%include "../source/syscall.inc"
PICM	equ 0x20 ;master PIC
PIC_EOI equ 0x20 ;end of interrupt code

start:
;set video mode
	mov		ax,		0x0013
	int		0x10

	push	es		;save OS ptr on vram

	mov		ax,		0xA000
	mov		es,		ax	;video buffer

	mov		ax,		0x8020
	mov		bx,		SYSCALL_PIT_SET_FREQUENCY
	int		0x20
	mov		di,		pit_handler
	mov		bx,		SYSCALL_SET_PIT_INT
	int		0x20
.lp:
	sti
	hlt
	cli
	cmp		byte[is_running], 0
	jne		.lp
.end:
;set back video mode
	mov		ax,		0x0003
	int		0x10

	pop		es		;load OS ptr on vram
	retf

pit_handler:
	call	refrash

	call	draw_border
	mov		bx,		controller_1.pos
	mov		cx,		CONTROLLER_1_NUM_OF_PIXELS
	mov		si,		controller_1.color
	call	draw_object

	mov		bx,		controller_2.pos
	mov		cx,		CONTROLLER_2_NUM_OF_PIXELS
	mov		si,		controller_2.color
	call	draw_object

	mov		bx,		ball.pos
	mov		cx,		BALL_NUM_OF_PIXELS
	mov		si,		ball.color
	call	draw_object

	call	handle_input
	call	move

	mov		al,			PICM
	out		PIC_EOI,	al
	iret


refrash:
; clear the screen by scrolling up
	xor     di,     di
	mov     cx,     32000
	xor     ax,     ax
	rep		stosw
	retn


handle_input:
	mov		bx,		SYSCALL_GET_KEYBOARD_DATA
	int		0x20
	test	al,		al
	je		.end

	cmp		al,		0x01	;make esc
	je		.make_esc
	cmp		al,		0x11	;make w
	je		.make_up1
	cmp		al,		0xE9	;make up arrow
	je		.make_up2
	cmp		al,		0x1F	;make s
	je		.make_down1
	cmp		al,		0xEB	;make down arrow
	je		.make_down2
	cmp		al,		0x91	;break w
	je		.break_up1
	cmp		al,		0xC8	;break up arrow
	je		.break_up2
	cmp		al,		0x9F	;break s
	je		.break_down1
	cmp		al,		0xD0	;break down arrow
	je		.break_down2
	retn
.make_esc:
	mov		byte[is_running],	0
	retn
.make_up1:
	mov		byte[moving_up1],	1
	retn
.make_up2:
	mov		byte[moving_up2],	1
	retn
.make_down1:
	mov		byte[moving_down1],	1
	retn
.make_down2:
	mov		byte[moving_down2],	1
	retn
.break_up1:
	mov		byte[moving_up1],	0
	retn
.break_up2:
	mov		byte[moving_up2],	0
	retn
.break_down1:
	mov		byte[moving_down1],	0
	retn
.break_down2:
	mov		byte[moving_down2],	0
.end:
	retn

move:
	cmp		byte[moving_up1], 1
	jne		.not_move_up1

	mov		ax,		-PIXELS_WIDTH * 3
	mov		bx,		controller_1.pos
	mov		cx,		CONTROLLER_1_NUM_OF_PIXELS
	call	move_object

	mov		cx,		CONTROLLER_1_NUM_OF_PIXELS
	call	check_collision_border
	test	cx,		cx
	jne		.not_move_up1

	mov		ax,		PIXELS_WIDTH * 3
	mov		cx,		CONTROLLER_1_NUM_OF_PIXELS
	call	move_object
	retn
.not_move_up1:
	cmp		byte[moving_down1], 1
	jne		.not_move_down1

	mov		ax,		PIXELS_WIDTH * 3
	mov		bx,		controller_1.pos
	mov		cx,		CONTROLLER_1_NUM_OF_PIXELS
	call	move_object

	mov		cx,		CONTROLLER_1_NUM_OF_PIXELS
	call	check_collision_border
	test	cx,		cx
	jne		.not_move_down1

	mov		ax,		-PIXELS_WIDTH * 3
	mov		cx,		CONTROLLER_1_NUM_OF_PIXELS
	call	move_object
	retn
.not_move_down1:
	cmp		byte[moving_up2], 1
	jne		.not_move_up2

	mov		ax,		-PIXELS_WIDTH * 3
	mov		bx,		controller_2.pos
	mov		cx,		CONTROLLER_2_NUM_OF_PIXELS
	call	move_object

	mov		cx,		CONTROLLER_2_NUM_OF_PIXELS
	call	check_collision_border
	test	cx,		cx
	jne		.not_move_up2

	mov		ax,		PIXELS_WIDTH * 3
	mov		cx,		CONTROLLER_2_NUM_OF_PIXELS
	call	move_object
	retn
.not_move_up2:

	cmp		byte[moving_down2], 1
	jne		.not_move_down2

	mov		ax,		PIXELS_WIDTH * 3
	mov		bx,		controller_2.pos
	mov		cx,		CONTROLLER_2_NUM_OF_PIXELS
	call	move_object

	mov		cx,		CONTROLLER_2_NUM_OF_PIXELS
	call	check_collision_border
	test	cx,		cx
	jne		.not_move_down2

	mov		ax,		-PIXELS_WIDTH * 3
	mov		cx,		CONTROLLER_2_NUM_OF_PIXELS
	call	move_object
.not_move_down2:
	retn


clear_if_move:
	mov		cx,		word[moving_up1]
	jcxz	.not_moving_1
	mov		bx,		controller_1.pos
	mov		cx,		CONTROLLER_1_NUM_OF_PIXELS
	call	clear_object
.not_moving_1:
	mov		cx,		word[moving_up2]
	jcxz	.not_moving_2
	mov		bx,		controller_1.pos
	mov		cx,		CONTROLLER_1_NUM_OF_PIXELS
	call	clear_object
.not_moving_2:
	retn


clear_object:
;in:
;	 bx = pos array of object
;	 cx = num of pixels of the object
;out: change the cx, si, di, al
;	 al = last color in object
;	 cx = -1
;	 di = last pixel pos in object
	xor		al,		al
.lp:
	mov		di,		cx
	shl		di,		1
	mov		di,		word[bx + di]
	stosb	;push pixel to VRAM
	dec		cx
	jns		.lp
	retn


draw_object:
;in:
;	 bx = pos array of object
;	 cx = num of pixels of the object
;	 si = color array of object
;out: change the cx, si, di, al
;	 al = last color in object
;	 cx = -1
;	 si = si + cx (from in)
;	 di = last pixel pos in object
.lp:
	mov		di,		cx
	shl		di,		1
	mov		di,		word[bx + di]
	lodsb	;get pixel color
	stosb	;push pixel to VRAM
	dec		cx
	jns		.lp
	retn


move_object:
;in:
;	 ax = move points
;	 bx = pos array of object
;	 cx = num of pixels of the object
;out:
.lp:
	mov		di,		cx
	shl		di,		1
	add		di,		bx
	add		word[di],	ax
	dec		cx
	jns		.lp
	retn


BORDER_WIDTH equ 2
draw_border:
	mov		ax,		0x5050

;up border
	xor		di,		di
	mov		cx,		PIXELS_WIDTH * BORDER_WIDTH
	rep		stosw

;down border
	mov		di,		PIXELS_WIDTH * 196
	mov		cx,		PIXELS_WIDTH * BORDER_WIDTH
	rep		stosw
	retn


check_collision_border:
;in:
;	 bx = pos array of object
;	 cx = num of pixels of the object
;out:
;	 cx = 0 if collision, 1 if not
	mov		bp,		cx ;end iterator
	shl		bp,		1  ;end iterator
	add		bp,		bx ;end iterator

	xor		cx,		cx
	mov		si,		bx
.lp:
	lodsw
	cmp		ax,		PIXELS_WIDTH * 4
	jbe		.end
	cmp		ax,		PIXELS_WIDTH * 196
	jae		.end
	cmp		si,		bp
	jne		.lp

	inc		cx
.end:
	retn


CONTROLLER_WIDTH_OFFSET equ 4  ; margin from edge of width
controller_1:
	.pos:	; it's start positions
		dw (50 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (51 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (52 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (53 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (54 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (55 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (56 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (57 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (58 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (59 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (60 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (61 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (62 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (63 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (64 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (65 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (66 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (67 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (68 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (69 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (70 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (71 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (72 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (73 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET
		dw (74 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET

		dw (50 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (51 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (52 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (53 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (54 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (55 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (56 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (57 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (58 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (59 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (60 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (61 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (62 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (63 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (64 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (65 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (66 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (67 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (68 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (69 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (70 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (71 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (72 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (73 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
		dw (74 * PIXELS_WIDTH) + CONTROLLER_WIDTH_OFFSET + 1
	.color:
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44

		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
		db	44
	CONTROLLER_1_NUM_OF_PIXELS equ (($ - controller_1) / 3) - 1

CONTROLLER_2_WIDTH_OFFSET equ PIXELS_WIDTH - CONTROLLER_WIDTH_OFFSET
controller_2:
	.pos:	; it's start positions
		dw (50 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (51 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (52 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (53 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (54 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (55 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (56 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (57 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (58 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (59 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (60 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (61 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (62 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (63 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (64 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (65 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (66 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (67 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (68 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (69 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (70 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (71 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (72 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (73 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET
		dw (74 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET

		dw (50 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (51 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (52 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (53 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (54 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (55 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (56 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (57 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (58 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (59 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (60 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (61 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (62 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (63 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (64 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (65 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (66 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (67 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (68 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (69 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (70 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (71 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (72 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (73 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
		dw (74 * PIXELS_WIDTH) + CONTROLLER_2_WIDTH_OFFSET + 1
	.color:
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36

		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
		db	36
	CONTROLLER_2_NUM_OF_PIXELS equ (($ - controller_2) / 3) - 1

ball:
	.pos:
		dw (PIXELS_WIDTH / 2) * (PIXELS_HEIGHT / 2)
		dw 1 + (PIXELS_WIDTH / 2) * (PIXELS_HEIGHT / 2)
		dw 2 + (PIXELS_WIDTH / 2) * (PIXELS_HEIGHT / 2)
		dw 3 + (PIXELS_WIDTH / 2) * (PIXELS_HEIGHT / 2)
		dw 4 + (PIXELS_WIDTH / 2) * (PIXELS_HEIGHT / 2)
		dw 5 + (PIXELS_WIDTH / 2) * (PIXELS_HEIGHT / 2)
		dw 6 + (PIXELS_WIDTH / 2) * (PIXELS_HEIGHT / 2)
		dw 7 + (PIXELS_WIDTH / 2) * (PIXELS_HEIGHT / 2)
		dw 8 + (PIXELS_WIDTH / 2) * (PIXELS_HEIGHT / 2)
		dw 9 + (PIXELS_WIDTH / 2) * (PIXELS_HEIGHT / 2)
	.color:
		db 36
		db 36
		db 36
		db 36
		db 36
		db 36
		db 36
		db 36
		db 36
		db 36
	BALL_NUM_OF_PIXELS equ (($ - ball) / 3) - 1

PIXELS_WIDTH equ 320
PIXELS_HEIGHT equ 200

is_running db 1

moving_up1 db 0
moving_down1 db 0

moving_up2 db 0
moving_down2 db 0
