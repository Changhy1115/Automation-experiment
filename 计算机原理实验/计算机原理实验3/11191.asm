data segment para
   buf db 50
       db ?
       db 50 dup(?)
   buft db 50 dup(0)
   total dw ?
   data1 dw 0
   data2 db 0
   data3 db 0
   data4 db 0
   data5 db 0
   ten db 10 
   str1 db 'My name is changhaiying 201795114',0ah,0dh,'$'
   str2 db 'Please input the total of nums:',0ah,0dh,'$'
   str3 db 'Please input nums ',0ah,0dh,'$'
   str4 db 'The average score is:$'	
   str5 db 0ah,0dh,'$'
data ends

ssg segment stack
   db 100 dup(?)
ssg ends

code segment
  main proc far
    	assume cs:code,ds:data,ss:ssg
    	mov ax,data
    	mov ds,ax 
	lea dx,str1
	mov ah,09h
	int 21h
	lea dx,str2
	mov ah,09h
	int 21h
	

	lea dx,buf
	mov ah,0ah
	int 21h 
	call convert 
	mov cl,al 
	and ch,00h
	mov total,cx 
	lea di,buft 
	call chgln 

	lea dx,str3
	mov ah,09h
	int 21h
	
circle:	lea dx,buf
	mov ah,0ah
	int 21h 
	call convert
	mov [di],al 
	inc di 
	call chgln 
	loop circle


	call accum
	call average
	call conver
	call disp
	mov ax,4c00h
	int 21h     
  main endp

chgln proc 
	lea dx,str5
    	mov ah,09h
    	int 21h
	ret
chgln endp


convert proc 
	mov si,dx
	inc si
	mov bl,[si] 
	and bh,00h
	inc si

	mov al,0 
	cmp byte ptr [si],'-' 
	jnz circle0 
	mov dx,0ffffh 
	inc si 
	dec bx 

circle0:mul ten
	sub byte ptr [si],30h 
	add al,[si]
	inc si
	dec bx
	jnz circle0
	
	cmp dx,0ffffh 
	jnz back
	neg al
back:	ret
convert endp


accum proc
	mov cx,total
	lea bx,buft
	mov ax,0
circle1:add al,[bx]
	adc ah,0
	inc bx
        loop circle1
	mov data1,ax
	ret
accum endp


average proc
	mov bx,total
	div bl
	and ah,00h
	mov data2,al
	ret
average endp


conver proc
	div ten
	mov data5,ah
	and ah,00h
	div ten
	mov data4,ah
	mov data3,al
	ret	
conver endp


disp proc
	lea dx,str4
	mov ah,09h
	int 21h 
	mov dl,data3
	call print
	mov dl,data4
	call print
	mov dl,data5
	call print
        call  chgln 
	ret 
disp endp


print proc 
	add dl,30h
	mov ah,2
	int 21h
	ret
print endp
code ends
end main
 
