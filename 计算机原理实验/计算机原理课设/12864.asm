;12864引脚: PC作为数据总线的输入
			;E(时钟线):PA7  	下降沿数据被写入12864
			;D/I(片选):PA6		0为选中
			;R/W:PA5			0写数据
;蜂鸣器：	PA4
			
;用一位拨码 PB0来选择档位
;用一位拨码 PB1来控制正反转

;			0：蜂鸣器指示按键(延时100ms)
;			1：AD控制直流电机
IO_ADDRESS  	equ 200h				;8255 IO控制
TIMER_ADDRESS	equ	210h			;8253 定时器控制
AD_IO			equ	220h				;
LED_IO			equ	230h
data segment
	LCD_CMD		db 	0					;12864控制字
	LCD_DAT		db 	0
	LCD_WORD	dw 	0
	PTA_temp	db 	0					;12864控制总线和
	delayms 	db 	0					;保存延时时间
	Switch		db	0					;保存拨码状态
	Beep_flag	db	0
	Duty		db	0
	MSG_name	dw	0B0A0h,0B0A0h,0B0A0h,0D5C5h,0EABFh,0B0A0h,0B0A0h,0B0A0h			;张昕
	MSG0		dw	0B0A0h,0B0A0h,0B2A6h,0C2EBh,0B5F7h,0CBD9h,0B0A0h,0B0A0h			;蜂鸣器
	MSG1		dw	0B0A0h,0B0A0h,0B5E7h,0CEBBh,0B5F7h,0CBD9h,0B0A0h,0B0A0h			;直流电机(ADC控制速度)
	led_hex		db	3fh,06h,5bh,4fh,66h,6dh,7dh,07h,7fh,67h,77H,7CH,39H,5EH,79H,71H
	led_dat		db	0

	
	Beep_mask	equ	10h
data ends

ss_seg segment stack
	db 256 dup(?)
ss_seg ends

code segment
	assume cs:code,ss:ss_seg,ds:data
START:
	cli									;关中断
	mov ax,	data
	mov	ds,	ax
	;初始化中断
	in	al, 21h
	and 	al, 11011111b				;开放IR5中断
	out	21h, al

	push	ds
	mov	ax, 0
	mov	ds, ax
	lea	ax, cs:inthandler
	mov	si, 35h							;中断类型码 35H
	add	si, si							;中断向量IP	35h*4
	add	si, si
	mov	ds:[si], ax						;把偏移地址赋值给ds:[si]
	push	cs							;CS值赋给AX
	pop	ax
	mov	ds:[si+2], ax					;段地址赋值给ds:[si+2]
	pop	ds
	
	
	;初始化8255
	mov	dx,	IO_ADDRESS
	add	dx,	3							;写控制寄存器
	mov	al,	82H							;10000010 A方式0输出 B方式0输入 C方式输出,作12864的数据输入
	out	dx,	al
	;初始化LCD
	lea	bx,	LCD_CMD
	mov byte ptr [bx],	30h				;开显示
	call LCD_write_cmd
	lea	bx,	LCD_CMD
	mov byte ptr [bx],	30h				;开显示
	call LCD_write_cmd
	lea	bx,	LCD_CMD
	mov byte ptr [bx],	0Ch				;开显示
	call LCD_write_cmd
	lea	bx,	LCD_CMD
	mov byte ptr [bx],	01h				;开显示
	call LCD_write_cmd
	lea	bx,	LCD_CMD
	mov byte ptr [bx],	06h				;开显示
	call LCD_write_cmd
	mov	ax,1
	call Disp_name						;显示名字
	
	;初始化8253
	mov	dx,	TIMER_ADDRESS+3
	mov	al,	36h
	out	dx,	al							;0通道 先低8位后高8位，方式3方波发生器，16位二进制计数		00110110
	mov ax, 5000						;分频系数5000，方波频率200HZ
	mov dx, TIMER_ADDRESS
	out dx,	al							;发送低字节
	mov	al, ah
	out dx, al							;发送高字节
	
	mov dx,	TIMER_ADDRESS+3
	mov	al,	74h							;1通道 先低8位后高8位，方式2分频器，16位二进制计数	01110100
	out dx, al
	mov ax, 10							;转速2-10
	mov dx, TIMER_ADDRESS+1
	out dx, al
	mov al, ah
	out dx, al
	
	
	;初始化ADC0809
	
	
	sti									;开中断
RUN:
	call Disp_name						;显示名字

	mov	dx, IO_ADDRESS+1
	in	al, dx
	lea bx, Switch
	mov [bx],al

	mov ah,0
	and al,07h
	mov bl,2
	div	bl
	add al,2
	lea bx,Duty
	mov byte ptr[bx],al
	
	
	lea bx, Switch
	and byte ptr [bx],01h
	cmp byte ptr [bx],0							;执行任务0
	JZ 	task0
	cmp byte ptr [bx],1							;执行任务1
	JZ	task1
task0:
	mov ax, 00h
	call Disp_line
	
	lea bx,Beep_flag
	mov al,[bx]
	and al,1
	cmp al,1
	jz beep_once
	cmp al,0
	jz over_temp
beep_once:
	lea bx, PTA_temp
	or byte ptr [bx],Beep_mask					;蜂鸣器位置1
	mov al,[bx]
	mov dx,IO_ADDRESS
	out	dx,	al
	
	lea	bx,	delayms
	mov	byte ptr [bx],	10h				;延时10h ms
	call 	LCD_delay
	
	lea bx, PTA_temp
	mov al, Beep_mask
	not al
	and [bx],al							;蜂鸣器位清0
	mov al,[bx]
	mov dx,IO_ADDRESS
	out	dx,	al
	
	lea bx,Beep_flag
	mov	byte ptr [bx],0							;标志位清0

over_temp:
	jmp over
	
task1:
	mov ax, 01h
	call Disp_line
	
	mov	dx, AD_IO
	out	dx, al								;此时AL数据无用
	
	add	dx, 2
	
	ask:
	in	al, dx
	test	al, 1
	jz	ask
	
	dec	dx
	in	al, dx
	mov ah, 0							;清空高8位
	mov bl, 024h
	div	bl								
	add al,2							;得到的数传给8253
	lea bx, Duty
	mov [bx],al
	
	lea		bx,	led_dat
	mov		[bx],al
	
	lea bx, PTA_temp
	and byte ptr [bx],0f0h
	or [bx],al
	mov dx, IO_ADDRESS
	mov al ,[bx]
	out dx, al
	          
over:
	;test
	lea bx, Duty
	mov al, [bx]
	lea	bx,	led_dat
	mov	[bx],al
	
	call led_disp
	mov dx,	TIMER_ADDRESS+3
	mov	al,	74h							;1通道 先低8位后高8位，方式2分频器，16位二进制计数	01110100
	out dx, al
	lea bx, Duty
	mov ax, [bx]
	mov dx, TIMER_ADDRESS+1
	out dx, al
	mov al, ah
	out dx, al
	
	jmp 	RUN
	
inthandler proc far
	push ax								;保护现场
	push dx
	
	lea bx,Beep_flag
	mov byte ptr [bx],1							;flag置1
	
	mov al,20h
	out 20h,al
	
	pop	dx								;恢复现场
	pop	ax
	sti
	iret
inthandler endp
	
	
	
LCD_write_cmd proc						;写入LCD_CMD的指令
	push	ax							;保护现场
	push	bx
	push	dx
	lea	bx,	LCD_CMD						;命令字保存在LCD_CMD中
	mov	al,	[bx]
	mov	dx,	IO_ADDRESS+2				
	out	dx,	al							;PTC输出数据
	mov	dx,	IO_ADDRESS
	lea bx,	PTA_temp
	mov	al,	[bx]
	and	al,	00011111b					;I,W
	out	dx,	al
	or	al,	10000000b					;E=1
	out	dx,	al
	lea	bx,	delayms
	mov	byte ptr [bx],1					;延时1ms
	call 	LCD_delay
	and	al,	01111111b					;E=0,产生下降沿
	out	dx,	al
	pop	dx								;恢复现场
	pop	bx
	pop	ax
	ret
LCD_write_cmd 	endp

LCD_write_data proc						;写入LCD_DAT的数据
	push	ax
	push	bx
	push	dx
	lea	bx,	LCD_DAT
	mov	al,	[bx]
	mov	dx,	IO_ADDRESS+2	
	out	dx,	al							;PTC输出数据
	mov	dx,	IO_ADDRESS
	lea bx,	PTA_temp
	mov	al,	[bx]
	and	al,	01011111b					;W=0,E=0
	or	al,	01000000b					;D=1
	out	dx,	al
	or	al,	10000000b					;E=1
	out	dx,	al
	lea	bx,	delayms
	mov	byte ptr [bx],	1				;延时1ms
	call 	LCD_delay
	and	al,	01111111b					;E=0
	out	dx,	al
	pop	dx
	pop	bx
	pop	ax
	ret
LCD_write_data 	endp

LCD_write_word proc						;写入LCD_DAT的数据
	push	ax
	push	bx
	push 	cx
	push	dx
	lea	bx,	LCD_WORD
	mov	ax,	[bx]
	lea	bx,	LCD_DAT
	mov	[bx],	ah
	call	LCD_write_data
	mov	[bx],	al
	call 	LCD_write_data
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
LCD_write_word 	endp

LCD_delay proc	;延时
	push	ax
	push	cx
	push	dx
	mov	dh,	delayms
L1:	
	mov	cx,	0180h
L2:
	loop	L2
	dec	dh
	JNZ	L1
	pop	dx
	pop	cx
	pop	ax
	ret
LCD_delay 	endp

Disp_line proc	;写入ax指示的行
	push	bx
	push	cx
	push	dx
	cmp	ax,0
	JZ	LINE0
	CMP	ax,1
	JZ	LINE1
LINE0:
	lea	bx,	LCD_CMD
	mov byte ptr [bx],	90h	;指向第二行
	call LCD_write_cmd
	lea	si,	MSG0
	jmp	DISP
LINE1:
	lea	bx,	LCD_CMD
	mov byte ptr [bx],	90h	;指向第二行
	call LCD_write_cmd
	lea	si,	MSG1
	jmp	DISP
DISP:
	lea	bx,	LCD_WORD
	mov	cx,	8
PUTCHAR:
	mov	ax,	[si]
	add	si,	2
	mov	word ptr [bx],	ax
	call 	LCD_write_word
	loop	PUTCHAR
	pop	dx
	pop	cx
	pop	bx
	ret
Disp_line 	endp


Disp_name proc	;写入ax指示的行
	push	bx
	push	cx
	push	dx
	lea	bx,	LCD_CMD
	mov byte ptr [bx],	80h	;指向第一行
	call LCD_write_cmd
	lea	si,	MSG_name
	lea	bx,	LCD_WORD
	mov	cx,	8
PUTCHAR2:
	mov	ax,	[si]
	add	si,	2
	mov	word ptr [bx],	ax
	call 	LCD_write_word
	loop	PUTCHAR2
	pop	dx
	pop	cx
	pop	bx
	ret
Disp_name 	endp

led_disp proc	;LED
	push	ax
	push	bx
	push	cx
	push	dx
	;call	speed_display
	lea		bx,	led_dat
	mov		al,	[bx]
	mov		ah,	0
	mov		si,	ax
	lea		bx,	led_hex
	mov		dx,	LED_IO+1
	mov		al,	01h		;??
	out		dx,	al
	mov		dx,	LED_IO
	mov		al,	[si+bx]
	out		dx,	al	
	
	pop		dx
	pop		cx
	pop		bx
	pop		ax
	ret
led_disp 	endp

code ends
	end start