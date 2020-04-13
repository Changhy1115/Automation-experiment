data 	segment	page
	buf	db	80h,7fh,00h,23h,98h,45h,77h,88h,00h,61h
	total	equ	($-buf)
	num	db	4 dup(0)
	str	db	0dh, 0ah, 'My name is Chang Haiying	201795114 $'
	str1	db	0dh, 0ah, 'the positive		: $'
	str2	db	0dh, 0ah, 'the zero		: $'
	str3	db	0dh, 0ah, 'the negative		: $'
	str4	db	0dh, 0ah, 'the total number	: $'
	tab	dw	str1,str2,str3,str4
	stri	db	0dh, 0ah, 'Please input a string:',0dh,0ah,'$'
	stro	db	0dh, 0ah, 'output the string :',0dh,0ah,'$'
	str5	db	50, ?, 50 dup (0)
data	ends

ssg	segment	para	stack
	dw	100 dup(0)
ssg	ends

code	segment	page
assume	cs:code,ds:data,ss:ssg
main 	proc	far
	mov	ax, data
	mov	ds, ax

	lea	dx, str		
	mov	ah, 9	
	int	21h

	lea	si, buf
	lea 	bx, num		;num[0]存储大于0的个数，[1]存储0的个数，[2]存储小于0的个数
	mov	cx, total
loop1:	mov	al, [si]
	cmp	al, 0
	je	zero
	jg	pos
	add	byte ptr [bx+2], 1	;小于0
	jmp 	next1

zero:	add	byte ptr [bx+1], 1	;等于0
	jmp	next1

pos:	add 	byte ptr [bx], 1	;大于0
	jmp	next1

next1:	inc	si
	loop    loop1

	mov	byte ptr [bx+3], total	;总数


	mov 	dx, 0a00h
        mov	di, 0
	mov	cx, 4
loop2:	push	dx
	push	ax
	mov	dx, [tab+di]
	mov	ah, 9
	int	21h
	add	di, 2
	pop	ax	
	pop	dx
	sub	ah, ah	
	mov	al, [bx]
	div	dh
	cmp	al, 0
	push	ax	
	je	next2
	call	bin2asc		;显示商al，即十位数
	call 	pchar
next2:	pop	ax		
	mov	al, ah		;显示余数ah,即个位数
	call	bin2asc
	call	pchar
	inc	bx
	loop	loop2

	lea	dx, stri	;输入提示信息显示
	mov	ah, 9		
	int	21h
	;输入
	lea	dx, str5
	mov	ah, 10
	int	21h	

	lea	bx, num
	mov	word ptr [bx], 0
	mov	word ptr [bx+2], 0

	lea	si, str5
	mov	cx, [si+1]
	and	cx, 0fh
	add	si, 2	;指向输入数据
	dec	cx
findc:	mov 	al, [si]
	cmp 	al, '-'
	je	neg2
	cmp	al, '0'
	je	zero2
	add	byte ptr [bx], 1	;小于0
	inc	si
	dec	cx
	jmp	loop4

neg2:	add	byte ptr [bx+2], 1	;小于0
	inc	si
	dec	cx
	jmp	loop4			;找,

zero2: 	add	byte ptr [bx+1], 1	;等于0
	inc	si
	dec	cx
	jmp 	loop4

loop4:	mov	al, [si]
	inc	si
	dec	cx
	cmp	al, ','
	je	findc
	cmp 	al, 0
	je	exit
	jmp	loop4

exit:	mov 	dx, 0a00h
        mov	di, 0
	mov	cx, 3
loop5:	push	dx
	push	ax
	mov	dx, [tab+di]
	mov	ah, 9
	int	21h
	add	di, 2
	pop	ax	
	pop	dx
	sub	ah, ah	
	mov	al, [bx]
	div	dh
	cmp	al, 0
	push	ax		
	je	next5
	call	bin2asc		
	call 	pchar
next5:	pop	ax		
	mov	al, ah		
	call	bin2asc
	call	pchar
	inc	bx
	loop	loop5

	mov	ax,4c00h
	int	21h
	
main	endp


bin2asc	proc
	and	al,0fh
	add	al,30h
	ret
bin2asc	endp

pchar	proc
	mov	ah,02h
	mov	dl,al
	int	21h
	ret
pchar	endp

code 	ends
end 	main
