.model small
.386
IO_ADDRESS	EQU	200H
data	segment
d1	dw	?
data	ends

code	segment
assume cs:code,ds:data
start:
	mov ax,data
	mov ds,ax
	mov dx,IO_ADDRESS
	add dx,3
	mov al,00110111B
	out dx,al
	mov dx,IO_ADDRESS
	mov ax,1000h
	out dx,al

	mov al,ah
	out dx,al

	mov dx,IO_ADDRESS
	add dx,3
	mov al,01110110B
	out dx,al
	mov dx,IO_ADDRESS
	inc dx
	mov ax,03e8h
	out dx,al
	mov al,ah
	out dx,al

ddd:
	jmp ddd
code	ends
end	start
