rand_int_seed dw 1
rand_int:
	mov		ax,		word[rand_int_seed]
	mov		dx,		0x053D
	mul		dx
	add		ax,		17205
	mov		word[rand_int_seed],	ax
	mov		bx,		326
;	div		bx
;	add		ax,		dx
	retn

set_rand_seed:
	mov		word[rand_int_seed],	ax
	retn
