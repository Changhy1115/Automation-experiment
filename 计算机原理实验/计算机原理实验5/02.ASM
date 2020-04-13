.model small
.386
AD_IO		equ	200h
LED_IO	equ	210h

data	segment	
	LEDCODE	DB	?
data	ends

code	segment
assume cs:code,ds:data
start:
	mov dx,LED_IO+3
	mov al,10000010b
	out dx,al
	
	mov ax,data
	mov ds,ax
RPT:
	mov dx,AD_IO
	out dx,al
	mov dx,AD_IO
	add dx,2

L1:
	in al,dx
	test al,01h
	jz L1
	mov dx,AD_IO
	inc dx
	in al,dx
	call DISP
	call DELAY
	jmp RPT

DISP	PROC
	mov	dx,LED_IO
	out	dx,al
	ret
DISP	ENDP

DELAY	PROC
	push cx
	mov cx,50h
X1:
	loop X1
	pop cx
	ret
DELAY	ENDP

code ends 
end start