data	segment page
	buf	db	80h,7fh,00h,23h,98h,45h,77h,88h,00h,61h
	count	equ	$-buf
	;num	db	4 dup(?)
	buf1	db	'My name is Chang Haiying  201795114',0dh,0ah,'$'
	buf2	db	0dh,0ah,'$'
	str1	db	'number of positive is :','$'
	str2	db	'number of zero is     :','$'
	str3	db	'number of negative is :','$'
	str4	db	'number	of total is    :','$'
	tab	dw	str1,str2,str3,str4

	data1	db	?	  ;zhengshu
	data2	db	?	  ;0
	data3	db	?	  ;fushu
	data4	db	'10','$'	;total
data	ends

ssg	segment page
	dw	100 	dup(?)
ssg	ends

code	segment page
	assume cs:code,ds:data,ss:ssg
start:	mov	ax,data
	mov	ds,ax
	lea	dx,buf1		;œ‘ æname
	mov	ah,09h
	int	21h
	
	lea	bx,buf
	mov	ax,00h
	mov	cx,count
	
work:	mov	al,[bx]
	push	bx
	CALL	near ptr compare
	pop	bx
	inc 	bx
	loop	work

	lea	dx,str1		;display number of positive
	mov	ah,09h
	int	21h
	lea	bx,data1
	mov	dl,[bx]
	add	dl,'0'
	mov	ah,02h
	int	21h
	lea	dx,buf2
	mov	ah,09h
	int	21h

	lea	dx,str2		;display number of zero
	mov	ah,09h
	int	21h
	lea	bx,data2
	mov	dl,[bx]
	add	dl,'0'
	mov	ah,02h
	int	21h
	lea	dx,buf2
	mov	ah,09h
	int	21h

	lea	dx,str3		;display number of negative
	mov	ah,09h
	int	21h
	lea	bx,data3
	mov	dl,[bx]
	add	dl,'0'
	mov	ah,02h
	int	21h
	lea	dx,buf2
	mov	ah,09h
	int	21h


	lea	dx,str4		;display number of total
	mov	ah,09h
	int	21h
	lea	dx,data4
	mov	ah,09h
	int	21h
	lea 	dx,buf2					
	mov	ah,09H
	int	21h

    	mov 	ax,4c00h
    	int 	21h

compare proc	near
	cmp	al,0
	jz	zero
	cmp	al,0
	jl	negative
	lea	bx,data1
	mov	al,[bx]
	inc	al
	mov	[bx],al
	ret

zero:
	lea	bx,data2
	mov	al,[bx]
	inc	al
	mov	[bx],al
	ret

negative:
	lea	bx,data3
	mov	al,[bx]
	inc	al
	mov	[bx],al
	ret
compare endp

code	ends
end	start