data	segment	page
buf	dw	80,100,100,80,75,66,58,100,69,95,80,100,100,80,75,66,58,100,69,95,80,100,100,80,75,66,58,100,69,95
count	equ	($-buf)/2	
num	equ	30
data1	dw	0;sum
data2	db	0
data3	db	0
data4	db	0
data5	db	0

buf1	db	'my name is Changhaiying 201795114',0dh,0ah,'$'
buf2	db	0dh,0ah,'$'
buf3	db	'The average score is :','$'
buf4	db	'The scores are 80,100,100,80,75,66,58,100,69,95,80,100,100,80,75,66,58,100,69,95,80,100,100,80,75,66,58,100,69,95',0ah,0dh,'$'
data	ends

ssg	segment	stack	page
	dw	100 	dup(?)
ssg	ends

code	segment	page
	assume	cs:code,ds:data,ss:ssg
main	proc	far
start:
mov	ax,data
mov	ds,ax

lea	dx,buf1
mov	ah,09h
int	21h

lea	dx,buf4
mov	ah,09h
int	21h

call	accum
call	average
call	conver

lea	dx,buf3
mov	ah,09h
int	21h

call	display

mov	ax,4c00h
int	21h
main	endp

;求和
accum	proc
mov	cx,num
lea	bx,buf

lea	si,data1
mov	ax,0

loop1:
	add	ax,[bx]
	add	bx,2
	loop	loop1

mov	[si],ax
ret
accum	endp

;求平均
average	proc

mov	ax,data1

mov	bl,num
div	bl	;div不能是立即数

mov	data2,al

ret
average	endp

;将data2转化成data3 4 5 三位bcd
conver	proc
lea	si,data2
mov	ax,[si]

mov	bl,100
div	bl

lea	bx,data3
mov	[bx],al	;百位数给data3

mov	al,ah;余数存入ax
xor	ah,ah

mov	bl,10
div	bl

lea	bx,data4
mov	[bx],al	;十位数给data4

lea	bx,data5
mov	[bx],ah

xor	ax,ax

ret
conver	endp


;显示BCD码
display	proc

mov	dl,data3
add	dl,30h

mov	ah,02h
int	21h

mov	dl,data4
add	dl,30h

mov	ah,02h
int	21h

mov	dl,data5
add	dl,30h

mov	ah,02h
int	21h

ret
display	endp


code	ends
end	start











