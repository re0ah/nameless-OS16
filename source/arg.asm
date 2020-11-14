;that is temporary args for calling process. Because this is
;singletask os, and there is haven't process structure (and
;argc & argv in them) argc & argv stored in kernel temporaly for
;calling process. If process calling another process, them
;argc & argv will be rewriting.
arg_argc db 0
arg_argv times 16 dw 0
;for getting argc & argv in the process need call corresponding
;system calls (see syscall.inc)
_interrupt_get_argc:
;in:
;out: bl = arg_argc
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	mov		bl,		byte[arg_argc]
	pop		ds
	retn

_interrupt_get_argv:
;in:  al = 
;out: bx = ptr to 
	push	ds
	mov		bx,		KERNEL_OFFSET
	mov		ds,		bx
	movzx	bx,		byte[arg_argc]
	pop		ds
	retn
