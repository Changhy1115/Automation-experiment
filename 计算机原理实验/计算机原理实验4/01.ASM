.model small
.386
IO_ADDRESS equ 200h
code segment
assume cs:code
start:
	mov dx,IO_ADDRESS+3
	mov al,10001001b 
	out dx,al
x1:
	mov	dx,IO_ADDRESS+1
	in	al,dx
	dec   dx
	out	dx,al		
	jmp	x1
code	ends
end	start