IO_ADDRESS equ 200h
TIMER_ADDRESS	equ	210h
AD_IO	equ	220h
LED_IO	equ	230h
data segment
	stepper 	db 	01H,03H,02H,06H,04H,0CH,08H,09H	;八拍时序
	speed		db	50
	dir			db	0
	step_now	db 	0
	ad_result	db	0
	led_hex		db	3fh,06h,5bh,4fh,66h,6dh,7dh,07h,7fh,67h;0-9字形码
	led_seg 	db	0
	led_dat		db	0
	delayms 	db 	0
	LCD_CMD		db 	0
	LCD_DAT		db 	0
	LCD_WORD	dw 	0
	PTA_temp	db 	0
	MSG1	dw	0B2BDh,0BDF8h,0B5E7h,0BBFAh,0A1EFh,0B8B6h,0B4BAh,0B7BDh	;步进电机-付春方
	MSG2	dw	0A9B3h,0A9A5h,0A9A5h,0A9A5h,0A9A5h,0A9A5h,0A9A5h,0A9B7h	;框
	MSG3	dw	0A9A7h,0B7BDh,0CFF2h,0A1FAh,0CBD9h,0B6C8h,0A3B0h,0A9A7h	;MSG3+6方向0A1FAh MSG3+12速度
	MSG4	dw	0A9BBh,0A9A5h,0A9A5h,0A9A5h,0A9A5h,0A9A5h,0A9A5h,0A9BFh	;框
data ends
code segment
	assume cs:code,ds:data
START:
	cli
	mov ax,	data
	mov	ds,	ax
	;8255 init
	mov	dx,	IO_ADDRESS
	add	dx,	3
	mov	al,	82H	;10000010bA输出 B输入
	out	dx,	al
	;lcd init
	lea	bx,	LCD_CMD
	mov byte ptr [bx],	0Ch	;指令：开显示00001100b
	call LCD_write_cmd
	mov	ax,1
	call Disp_line
	mov	ax,2	
	call Disp_line
	mov	ax,3
	call Disp_line
	mov	ax,4	
	call Disp_line
	;step_now init
	lea	bx,	step_now
	mov	byte ptr [bx],	0
	;8254 init
	mov	dx,	TIMER_ADDRESS
	add 	dx, 3
	mov 	al, 01110111b	;CNT1 BCD 16bit mode3
	out 	dx, al
	mov 	dx, TIMER_ADDRESS
	inc	dx			;CNT1 
	mov 	al, 0			;10000分频
	out 	dx, al
	out 	dx, al		;BCD0
	mov 	dx, TIMER_ADDRESS
	add 	dx, 3
	mov 	al, 10110110b	;CNT2 bin 16bit mode3
	out 	dx, al
	mov 	dx, TIMER_ADDRESS
	add 	dx, 2			;CNT2
	mov 	ax, 20;		;20分频
	out 	dx, al
	mov 	al, ah
	out 	dx, al			
	;CLK1-1MHz,OUT1-100Hz-CLK2,OUT2-5Hz
	;interrupt init
	;设置中断屏蔽字 主片
	in	al,	21h
	and	al,	11011011b	;开放MIR5 MIR2(SIR0)
	out	21h,	al
	;从片
	in	al,	0a1h
	and	al,	11111110b	;SIR0
	out	0a1h,	al
	;设置中断向量表
	push	ds
	mov	ax,	0
	mov	ds,	ax
	lea	ax,	cs:PIT_IRQ_HANDLER	;AX指向中断程序入口地址
	mov	si,	70h			;SIR0中断类型码
	add	si,	si
	add	si,	si
	mov	ds:[si],	ax	;中断向量表IP
	push	cs
	pop	ax
	mov	ds:[si+2],	ax	;中断向量表CS

	mov	ax,	0
	mov	ds,	ax
	lea	ax,	cs:AD_IRQ_HANDLER	;AX指向中断程序入口地址
	mov	si,	35h			;MIR5中断类型码
	add	si,	si
	add	si,	si
	mov	ds:[si],	ax	;中断向量表IP
	push	cs
	pop	ax
	mov	ds:[si+2],	ax	;中断向量表CS
	pop	ds
	call 	AD_START
	sti				;开中断
RUN:
	call 	delay
	call 	step
	call 	Disp_data
	call	led_disp
	jmp 	RUN

AD_IRQ_HANDLER proc	far	;中断函数(AD采集)
	push	ax
	push	dx
	mov 	dx, AD_IO	;读AD
	inc 	dx
	in 		al, dx;读入AD值
	lea		bx,	ad_result
	mov		[bx],	al
	mov		al,	20h;发送中断结束命令
	out		20h,	al
	pop		dx
	pop		ax
	sti
	iret
AD_IRQ_HANDLER endp
	
PIT_IRQ_HANDLER proc	far	;定时中断
	push	ax
	push	dx
	call	read_switch
	lea	bx,	dir	;更新方向信息
	mov 	al,	[bx]
	lea	bx,	MSG3
	cmp	al,	0
	JZ	LEFT
	mov	word ptr [bx+6],	0A1FBh	;右
	jmp	RIGHT
LEFT:	
	mov	word ptr [bx+6],	0A1FAh	;左
RIGHT:
	mov	al,	20h		;发送中断结束命令SIR0
	out	0a0h,	al
	mov	al,	20h		;发送中断结束命令MIR2(SIR0)
	out	20h,	al
	call 	AD_START
	pop	dx
	pop	ax
	sti
	iret
PIT_IRQ_HANDLER endp
	
read_switch proc
	push	ax
	push	bx
	push	cx
	push	dx
	MOV	DX,	IO_ADDRESS	;读入B
	inc	dx
	IN	AL,	DX
	and	al,	80h		;10000000b取最高位作为方向
	lea	bx,	dir		;dir取值80h或00h
	mov	[bx],	al

	lea	bx,	ad_result
	mov	al,	[bx]
	shr 	al,	1
	shr 	al,	1		
	shr 	al,	1		;除以8 0-31
	add	al,	5		;取值5-36
	lea	bx,	speed		;电位器调速
	mov	[bx],	al
	dec	al
	shr	al,	1
	shr	al,	1		;除以4
	mov	ah,	9
	sub	ah,	al
	mov	al,	ah		;al取值1-8
	mov	ah,	0
	lea 	bx,	led_dat		;数码管数值
	mov	[bx],	al
	lea	bx,	MSG3
	add	ax,	0A3B0h		;码制转化
	mov	[bx+12],	ax		;+12，修改速度
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
read_switch endp

AD_START proc	;AD开始转换
	mov dx,AD_IO
	out dx,al
	ret
AD_START endp

delay proc	;延时,通过speed值改变两个节拍之间延时时间,调节步进电机速度
	push	ax
	push	cx
	push	dx
	mov	dh,	speed
x1:	
	mov	cx,	0180h
x2:
	loop	x2
	dec	dh
	JNZ	x1	;!=0
	pop	dx
	pop	cx
	pop	ax
	ret
delay 	endp

step proc	;步进
	push	ax
	push	bx
	push	dx
	mov	ax,	0
	lea	bx,	step_now
	mov	al,	byte ptr [bx]
	mov	si,	ax
	cmp	dir,	0	;方向
	JZ	FORWARD	;=0
	dec	si
	JMP OUTPUT_STEP
FORWARD:
	inc si
OUTPUT_STEP:
	cmp si,	0
	JNL	NOT_MIN	;>=,反转循环
	mov	si,	7
NOT_MIN:
	cmp	si,	7
	JLE	NOT_MAX	;<=,正转循环
	mov	si,	0
NOT_MAX:
	mov	dx,	IO_ADDRESS
	lea 	bx, stepper
	mov	al,	[bx+si];输出一个节拍
	out 	dx,	al
	lea 	bx,	PTA_temp
	mov	[bx],	al
	lea	bx,	step_now
	mov	ax,	si
	mov	byte ptr [bx],	al

	lea	bx,	led_dat
	mov	ah,	[bx]
	cmp	ah,	7
	JNGE	NON_ALARM_HIGH
	JNLE	ALARM_HIGH
NON_ALARM_HIGH:		
	JMP	OUTPUT1
ALARM_HIGH:
	or	PTA_temp,	00010000b
	JMP	OUTPUT1
OUTPUT1:
	mov	dx,	IO_ADDRESS;速度过快蜂鸣器报警
	mov	al,PTA_temp
	out 	dx,al

	cmp	ah,	2
	JNLE	NON_ALARM_LOW
	JNGE	ALARM_LOW
NON_ALARM_LOW:		
	JMP	OUTPUT2
ALARM_LOW:
	or	PTA_temp,	00010000b
	JMP	OUTPUT2
OUTPUT2:
	mov	dx,	IO_ADDRESS;速度过快蜂鸣器报警
	mov	al,PTA_temp
	out 	dx,al
	


	pop	dx
	pop	bx
	pop	ax
	ret
step	endp

Disp_line proc	;写入ax指示的行
	push	bx
	push	cx
	push	dx
	cmp	ax,4
	JZ	LINE4
	CMP	ax,3
	JZ	LINE3
	CMP	ax,2
	JZ	LINE2
LINE1:
	mov byte ptr [bx],	80h	;指令：指向第一行
	call LCD_write_cmd
	lea	si,	MSG1
	jmp	DISP
LINE2:
	mov byte ptr [bx],	90h	;指令：指向第二行
	call LCD_write_cmd
	lea	si,	MSG2
	jmp	DISP
LINE3:
	mov byte ptr [bx],	88h	;指令：指向第三行
	call LCD_write_cmd
	lea	si,	MSG3
	jmp	DISP
LINE4:
	mov byte ptr [bx],	98h	;指令：指向第四行
	call LCD_write_cmd
	lea	si,	MSG4
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


LCD_write_cmd proc	;写入LCD_CMD的指令
	push	ax
	push	bx
	push	dx
	lea	bx,	LCD_CMD
	mov	al,	[bx]
	mov	dx,	IO_ADDRESS+2	
	out	dx,	al			;PTC输出数据
	mov	dx,	IO_ADDRESS
	lea 	bx,	PTA_temp
	mov	al,	[bx]
	and	al,	00011111b	;A6A7置0,写命令I,W
	out	dx,	al
	or	al,	10000000b	;开使能,E=1
	out	dx,	al
	lea	bx,	delayms
	mov	byte ptr [bx],	1
	call 	LCD_delay
	and	al,	01111111b	;E=0
	out	dx,	al
	pop	dx
	pop	bx
	pop	ax
	ret
LCD_write_cmd 	endp
	
LCD_write_data proc	;写入LCD_DAT的数据(一个字节)
	push	ax
	push	bx
	push	dx
	lea	bx,	LCD_DAT
	mov	al,	[bx]
	mov	dx,	IO_ADDRESS+2	
	out	dx,	al			;PTC输出数据
	mov	dx,	IO_ADDRESS
	lea 	bx,	PTA_temp
	mov	al,	[bx]
	and	al,	01011111b	;W=0,E=0
	or	al,	01000000b	;D=1
	out	dx,	al
	or	al,	10000000b	;E=1
	out	dx,	al
	lea	bx,	delayms
	mov	byte ptr [bx],	1
	call 	LCD_delay
	and	al,	01111111b	;E=0
	out	dx,	al
	pop	dx
	pop	bx
	pop	ax
	ret
LCD_write_data 	endp
	
LCD_write_word proc	;写入LCD_DAT的数据(两个字节)
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
	mov	cx,	0090h
L2:
	loop	L2
	dec	dh
	JNZ	L1
	pop	dx
	pop	cx
	pop	ax
	ret
LCD_delay 	endp

Disp_data proc
	push	ax
	push	cx
	push	dx
	lea	bx,	LCD_CMD
	mov byte ptr [bx],	88h	;指向MSG3
	call LCD_write_cmd
	lea	bx,	LCD_WORD
	lea	si,	MSG3
	mov	cx,	8
PUTCH:
	mov	ax,	[si]
	add	si,	2
	mov	word ptr [bx],	ax
	call 	LCD_write_word
	loop	PUTCH
	pop	dx
	pop	cx
	pop	ax
	ret
Disp_data endp

led_disp proc	;数码管显示
	push	ax
	push	bx
	push	cx
	push	dx
	lea	bx,	led_dat
	mov	al,	[bx]
	mov	ah,	0
	mov	si,	ax
	lea	bx,	led_hex
	mov	dx,	LED_IO+1
	mov	al,	01h		;个位
	out	dx,	al
	mov	dx,	LED_IO
	mov	al,	[si+bx]
	out	dx,	al
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
led_disp 	endp

code ends
	end start