;https://www.youtube.com/watch?v=Sck7ufPfOWY
;it is port of demo, author is https://www.pouet.net/prod.php?which=85670

%include "../source/syscall.inc"

mov		ax,		0x0100
mov		bx,		SYSCALL_PIT_SET_FREQUENCY
int		0x20

mov		si,		0x0100
push	0xa000
pop		es
mov		ax,		0x4f02
mov		bx,		si
int		0x10
mov		bh,		0xf0
S:
mov		di,		-1
mov		bp,		di
mov		dx,		440
Y:
mov		cx,		640
X:
pusha
	mov		si,		dx
	add		dx,		cx
	sub		cx,		si
	sub		dx,		560
	jns		G
		neg		dx
	G:
	inc		dx
	sub		cx,		byte 80
	jns		G2
		neg		cx
	G2:
	inc		cx
	mov		ax,		dx
	cmp		ax,		cx
	jle		F
		mov		ax,		cx
	F:
	push	dx
		cwd
		xchg	si,		ax
		imul	ax,		bx,		byte -16
		div		si
	pop		dx
	imul	cx,		ax
	imul	dx,		ax
	add		ax,		bx
	or		dx,		cx
	xor		al,		dh
	sar		ax,		5
	and		al,		3
	imul	ax,		byte 24
	push	bx
	shr		bx,		9
	add		ax,		bx
	pop		bx
	add		al,		-40-24-24
	QQ:
	stosb
popa
inc		di
test	di,		di
jnz		ns
	inc		bp
	pusha
		mov		ax,		0x4f05
		xor		bx,		bx
		mov		dx,		bp
		int		0x10
	popa
ns:
loop	X
hlt
pusha
mov		bx,		SYSCALL_GET_KEYBOARD_DATA
int		0x20
cmp		al,		1  ;ESC
je		exit_esc
popa
dec		dx			
jnz		Y			
nm:
add		bx,		byte 6
in		al,		0x60
dec		al
hlt
ja		S
jmp		exit
exit_esc:
popa
exit:
;set back video mode
push	0xb800
pop		es
mov		ax,		0x0003
int		0x10
xor		ax,		ax  ;exit status
retf
