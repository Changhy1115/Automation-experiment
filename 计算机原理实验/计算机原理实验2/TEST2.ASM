data 	segment 
buf 	db 	80H,7FH,00H,23H,98H,45H,77H,88H,00H,61H
count 	equ 	$-buf
buf1	db	'my name is andy',0DH,0AH,'$'
buf2	db	0DH,0AH,'$'
buf3	db	' number of positive is ','$'
buf4	db	' number of negative is ','$'
buf5	db	' number of zero is ','$'
buf6	db	' number of total is ','$'
data1	db	'10','$'	;
data2	db	?	;
data3	db	?	;
data4	db	?	;
data	ends
ssg1	segment	stack
	dw	100 dup(?)
ssg1	ends
codes	segment	page
	assume	cs:codes,ds:data,ss:ssg1
start:  mov     ax,data
	mov	ds,ax
	lea	dx,buf1
	mov	ah,09H
	int	21H					;display string
	
	lea 	bx,buf
	mov	ax,00H
	mov 	cx,count

work:	mov	al,[bx]
	push	bx
	CALL	near ptr compare
	pop	bx
	inc 	bx
	loop	work
	
	lea 	dx,buf4					;display number of negative
	mov	ah,09H
	int	21H
	lea	bx,data2
	mov	dl,[bx]
	add	dl,'0'
	mov	ah,02H
	int	21H
	lea 	dx,buf2					
	mov	ah,09H
	int	21H
	
	lea	dx,buf3					;display number of positive
	mov	ah,09H
	int	21H
	lea	bx,data3
	mov	dl,[bx]
	add	dl,'0'
	mov	ah,02H
	int	21H
	lea 	dx,buf2					
	mov	ah,09H
	int	21H

	lea	dx,buf5					;display number of zero
	mov	ah,09H
	int	21H
	lea	bx,data4
	mov	dl,[bx]
	add	dl,'0'
	mov	ah,02H
	int	21H
	lea 	dx,buf2					
	mov	ah,09H
	int	21H


	lea	dx,buf6					;display number of zero
	mov	ah,09H
	int	21H
	lea	dx,data1
	mov	ah,09H
	int	21H


	lea 	dx,buf2					
	mov	ah,09H
	int	21H

    	mov 	ax,4C00H
    	int 	21H

compare proc 	near	;用于al中数的正负
	cmp	al,	0
	JZ	zero		;比较是否为零
	cmp	al,	0
	JL	minus		;比较是否为负
	lea	bx,	data3
	mov 	al,	[bx]
	inc	al			;正数个数加1
	mov	[bx],al
	ret
zero:				;零个数加1
	lea	bx,	data4
	mov 	al,	[bx]
	inc	al
	mov	[bx],al
	ret
minus:				;负数个数加1
	lea	bx,	data2
	mov 	al,	[bx]
	inc	al
	mov	[bx],al
	ret
compare endp


codes 	ends
    	end start
	
	
