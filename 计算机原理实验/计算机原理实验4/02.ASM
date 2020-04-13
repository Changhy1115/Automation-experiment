.model small
.386
data segment 
	count db 00h
	number db 00h
	i8255_a	equ	200h
	i8255_k	equ	203h
data	ends

code	segment
	assume	cs:code,ds:data
start:
 	cli
	mov	ax,data
	mov	ds,ax
	mov	es,ax
	
	mov	dx,i8255_k
	mov	al,80h
	out	dx,al

	mov	al,count
	mov	dx,i8255_a
	out	dx,al

	;设置8259中断屏蔽字
	in	al,21h
	and	al,11011111b
	out	21h,al

	;设置中断向量表
	push	ds
	mov		ax,0
	mov		ds,ax
	lea		ax,cs:int_proc
	mov		si,35h
	add		si,si
	add		si,si
	mov		ds:[si],ax
	push	cs
	pop		ax
	mov		ds:[si+2],ax
	pop		ds
	sti

	;等待中断
	mov		cx,0
LLL:	nop
	jmp		LLL


	;中断服务子程序
INT_PROC	proc far
	push	ax
	push	dx
QUERY:
	inc		cx
	cmp		cx,3
	jb		back
	inc		count
	mov		al,	count
	mov		dx,	i8255_a
	out		dx,	al
back:	
	cmp		cx,3
	jb		next
	mov		cx,0
next:	
	mov		al,20h
	out		20h,al
	pop		dx
	pop		ax
	sti
	iret
int_proc	endp
code	ends
end	start
	


