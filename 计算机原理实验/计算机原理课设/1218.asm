.model small
.386
IO_8255 equ 200h
IO_8254	equ	210h
AD_IO	equ	220h
LED_IO	equ	230h

data segment
	stepper 	db 	01H,03H,02H,06H,04H,0CH,08H,09H	;八拍时序
	speed		db	50								;步进电机速度
	dir			db	0								;步进电机方向
	step_now	db 	0								;指示当前的一拍时序
	AD_result	db	0								;AD转换的数字量
	led_hex		db	3fh,06h,5bh,4fh,66h,6dh,7dh,07h,7fh,6Fh;数码管0-9的数字码
	led_dat		db	0								;数码管将要显示的数值
	delayms 	db 	0								;延时基准量
	LCD_CMD		db 	0								;向12864写入的命令
	LCD_DAT		db 	0								;向12864写入的数据
	LCD_WORD	dw 	0								;向LCD写入的中文编码
	PTA_temp	db 	0								;暂存8255PA口当前的输出
	MSG1		dw	0B2BDh,0BDF8h,0B5E7h,0BBFAh,0A1AAh,0B3A3h,0BAA3h,0D3B1h	;步进电机-常海颖
	MSG2		dw	0B0A0h,0B5E7h,0D7D4h,0A3B1h,0A3B7h,0A3B0h,0A3B4h,0B0E0h	;电自1704班
	MSG3		dw	0B0A0h,0B7BDh,0CFF2h,0A1FAh,0CBD9h,0B6C8h,0A3B0h,0B0A0h	;MSG3+6方向0A1FAh MSG3+12速度
	MSG4		dw	0D6B8h,0B5BCh,0BDCCh,0CAA6h,0A1AAh,0D0BBh,0C0CFh,0CAA6h	;指导教师-谢老师
data ends

ss_ssg	segment
	dw	50 dup(0)
ss_ssg	ends

code segment
	assume cs:code,ds:data,ss:ss_ssg
START:
	cli							;关中断
	mov ax,data
	mov	ds,ax
;8255初始化
	mov	dx,IO_8255+3		;8255控制口
	mov	al,82H	   			;10000010bA输出 B输入
	out	dx,al

;lcd初始化
	lea	bx,LCD_CMD
	mov byte ptr [bx],0Ch	;开显示
	call LCD_write_cmd
	mov	ax,1
	call Disp_line			;显示第一行
	mov	ax,2	
	call Disp_line			;显示第二行
	mov	ax,3				
	call Disp_line			;显示第三行
	mov	ax,4
	call Disp_line			;显示第四行

;step_now init
	lea	bx,step_now
	mov	byte ptr [bx],0

;8254初始化
	mov	dx,IO_8254+3		;8254 control 213h
	mov al,01110111b		;CNT1 BCD计数 16bit 方式3(方波)
	out dx,al
	mov dx,IO_8254+1		;CNT1 ,211h
	mov al,0				;10000分频,得到100Hz
	out dx,al
	out dx,al				;BCD0
	mov dx,IO_8254+3		;213h
	mov al,10110110b		;CNT2 二进制计数 16bit 方式3
	out dx,al
	mov dx,IO_8254+2		;CNT2,212h
	mov ax,20;200			;20分频,得到5Hz
	out dx,al
	mov al,ah
	out dx,al	
;CLK1-1MHz,OUT1-100Hz-CLK2,OUT2-0.5Hz
	
	;设置中断屏蔽字
	;主片
	in	al,21h
	and	al,11011011b		;MIR5(AD) MIR2(SIR0)
	out	21h,al
	;从片
	in	al,0a1h
	and al,11111110b		;SIR0
	out	0a1h,al
	;设置中断向量表
	push	ds
	mov	ax,0
	mov	ds,ax
	lea	ax,cs:PIT_IRQ_HANDLER	;AX指向中断程序入口地址，进入定时中断
	mov	si,70h					;中断类型码,SIR0
	add	si,si
	add	si,si
	mov	ds:[si],ax				;中断向量表IP
	push	cs
	pop		ax
	mov	ds:[si+2],ax			;中断向量表CS
	;AD
	mov	ax,0
	mov	ds,ax
	lea	ax,cs:AD_IRQ_HANDLER	;AX指向中断程序入口地址
	mov	si,35h					;IRQ5(MIR5)
	add	si,si
	add	si,si
	mov	ds:[si],ax			;中断向量表IP
	push	cs
	pop		ax
	mov	ds:[si+2],ax			;中断向量表CS
	pop		ds
	call 	AD_START
	sti								;开中断
	
RUN:
	call 	delay					;延时50ms
	call 	step
	call 	Disp_data
	call	led_speed
	jmp 	RUN
	

;AD中断
AD_IRQ_HANDLER proc	far	
	push	ax
	push	dx
	mov dx,AD_IO			;读AD
	inc dx
	in 	al,dx				;读入AD值
	lea	bx,ad_result
	mov	[bx],al
	mov	al,20h				;发送中断结束命令EOI
	out	20h,al
	pop		dx
	pop		ax
	sti
	iret
AD_IRQ_HANDLER endp


;定时中断服务子程序
PIT_IRQ_HANDLER proc far
	push	ax
	push	dx				;保护现场
	call	read_switch		;读取速度方向
	lea	bx,dir				;更新方向信息
	mov al,[bx]
	lea	bx,MSG3
	cmp	al,0
	jz	LEFT
	mov	word ptr [bx+6],0A1FBh	;右
	jmp	RIGHT
LEFT:	
	mov	word ptr [bx+6],0A1FAh	;左
RIGHT:
	mov	al,20h			;发送中断结束命令SIR0
	out	0a0h,al
	mov	al,20h			;发送中断结束命令MIR2(SIR0)
	out	20h,al
	call 	AD_START
	pop		dx
	pop		ax
	sti
	iret
PIT_IRQ_HANDLER endp	

;速度读取处理
read_switch proc
	push	ax
	push	bx
	push	cx
	push	dx
	mov	dx,IO_8255+1		;读B口
	in	al,dx
	and	al,80h				;B7送dir 10000000b取最高位作为方向
	
	lea	bx,dir
	mov	[bx],al

	lea	bx,ad_result
	mov	al,[bx]				;取ad_result
	shr al,1
	shr al,1		
	shr al,1		;除以8 0-31
	add	al,5			;取值5-36
	lea	bx,speed		;电位器调速		
	mov	[bx],al	
	dec	al
	shr	al,1
	shr	al,1			;除以4
	mov	ah,9
	sub	ah,al
	mov	al,ah			;al取值1-8
	mov	ah,0
	lea bx,led_dat		;数码管数值
	mov	[bx],al
	lea	bx,MSG3
	add	ax,0A3B0h
	mov	[bx+12],ax		;+12，修改速度
	pop		dx
	pop		cx
	pop		bx
	pop		ax
	ret
read_switch endp



;启动AD转换
AD_START	proc	
	mov dx,AD_IO
	out dx,al
	ret
AD_START	endp

;延时,通过speed值改变两个节拍之间延时时间,调节步进电机速度
delay	proc	
	push	ax
	push	cx
	push	dx
	mov	dh,speed
x1:	
	mov	cx,0180h
x2:
	loop	x2
	dec	dh
	JNZ	x1	;!=0
	pop		dx
	pop		cx
	pop		ax
	ret
delay	endp


;步进电机相序输出
step	proc	
	push 	ax
	push 	bx
	push 	dx
	mov	ax,0
	lea	bx,step_now
	mov	al,byte ptr [bx]
	mov	si,ax
	cmp	dir,0		;方向
	jz	FORWARD		;=0
	dec	si
	JMP OUTPUT_STEP
FORWARD:
	inc si
OUTPUT_STEP:
	cmp si,0
	JNL	NOT_MIN		;>=,反转循环
	mov	si,7
NOT_MIN:
	cmp	si,7
	JLE	NOT_MAX		;<=,正转循环
	mov	si,0
NOT_MAX:
	mov	dx,IO_8255
	lea bx,stepper
	mov	al,[bx+si]	;输出一个节拍
	out dx,al
	lea bx,PTA_temp
	mov	[bx],al
	lea	bx,step_now
	mov	ax,si
	mov	byte ptr [bx],al

	lea	bx,led_dat
	mov	ah,[bx]
	cmp	ah,7
	JNGE	NON_ALARM_HIGH
	JNLE	ALARM_HIGH
NON_ALARM_HIGH:		
	JMP	OUTPUT1
ALARM_HIGH:
	or	PTA_temp,00010000b
	JMP	OUTPUT1
OUTPUT1:
	mov	dx,IO_8255;速度过快蜂鸣器报警
	mov	al,PTA_temp
	out dx,al

	cmp	ah,2
	JNLE	NON_ALARM_LOW
	JNGE	ALARM_LOW
NON_ALARM_LOW:		
	JMP	OUTPUT2
ALARM_LOW:
	or	PTA_temp,00010000b
	JMP	OUTPUT2
OUTPUT2:
	mov	dx,IO_8255;速度过快蜂鸣器报警
	mov	al,PTA_temp
	out dx,al
	pop		dx
	pop		bx
	pop		ax
	ret
step	endp

;数码管显示速度
speed_disp	proc
	push 	ax
	push 	bx
	push 	cx
	push 	dx
	lea	bx,led_dat
	mov	al,[bx]
	mov	ah,0
	mov	si,ax
	lea	bx,led_hex
	mov	dx,LED_IO+1
	mov	al,01h		;个位
	out	dx,al
	mov	dx,LED_IO
	mov	al,[si+bx]
	out	dx,al
	pop		dx
	pop		cx
	pop		bx
	pop		ax
	ret
speed_disp	endp 

;LCD显示第N行
Disp_line 	proc
	push 	bx
	push 	cx
	push 	dx
	cmp	ax,4
	jz	LINE4
	cmp	ax,3
	jz	LINE3
	cmp	ax,2
	jz	LINE2
LINE1:
	mov byte ptr [bx],80h	;指向第一行
	call LCD_write_cmd
	lea	si,MSG1
	jmp	DISP
LINE2:
	mov byte ptr [bx],90h	;指向第二行
	call LCD_write_cmd
	lea	si,MSG2
	jmp	DISP
LINE3:
	mov byte ptr [bx],88h	;指向第三行
	call LCD_write_cmd
	lea	si,MSG3
	jmp	DISP
LINE4:
	mov byte ptr [bx],98h	;指向第四行
	call LCD_write_cmd
	lea	si,MSG4
DISP:
	lea	bx,LCD_WORD
	mov	cx,8
PUT:
	mov	ax,[si]
	add	si,2
	mov	word ptr [bx],ax
	call LCD_write_word
	loop PUT
	pop		dx
	pop		cx
	pop		bx
	ret
Disp_line 	endp


;LCD写入相关子程序
;写入LCD_CMD的指令
LCD_write_cmd proc	
	push	ax
	push	bx
	push	dx
	lea	bx,LCD_CMD
	mov	al,[bx]
	mov	dx,IO_8255+2	
	out	dx,al					;PTC输出
	mov	dx,IO_8255
	lea bx,PTA_temp
	mov	al,[bx]
	and	al,00011111b			;A6A7置0,写命令I,W
	out	dx,al
	or	al,10000000b			;E=1 开使能
	out	dx,al
	lea	bx,delayms
	mov	byte ptr [bx],1  		;延时1ms
	call LCD_delay
	and	al,01111111b			;E=0
	out	dx,al
	pop		dx
	pop		bx
	pop		ax
	ret
LCD_write_cmd 	endp

;写入LCD_DAT数据	
LCD_write_data proc	
	push	ax
	push	bx
	push	dx
	lea	bx,LCD_DAT
	mov	al,[bx]
	mov	dx,IO_8255+2	
	out dx,al					;PTC输出
	mov	dx,IO_8255
	lea bx,PTA_temp
	mov	al,[bx]
	and	al,01011111b			;W=0,E=0
	or	al,01000000b			;D=1
	out	dx,al
	or	al,10000000b			;E=1
	out	dx,al
	lea	bx,delayms
	mov	byte ptr [bx],1
	call LCD_delay
	and	al,01111111b			;E=0
	out	dx,al
	pop		dx
	pop		bx
	pop		ax
	ret
LCD_write_data 	endp

;写入LCD_DAT数据	
LCD_write_word proc	
	push	ax
	push	bx
	push 	cx
	push	dx
	lea	bx,LCD_WORD 
	mov	ax,[bx]
	lea	bx,LCD_DAT
	mov	[bx],ah
	call	LCD_write_data
	mov	[bx],al
	call 	LCD_write_data
	pop		dx
	pop		cx
	pop		bx
	pop		ax
	ret
LCD_write_word 	endp

;LCD延时，用于写入数据之间	
LCD_delay proc
	push	ax
	push	cx
	push	dx
	mov	dh,delayms
L1:	
	mov	cx,0090h
L2:
	loop	L2
	dec	dh
	jnz	L1
	pop		dx
	pop		cx
	pop		ax
	ret
LCD_delay 	endp

Disp_data proc
	push	ax
	push	cx
	push	dx
	lea	bx,LCD_CMD
	mov byte ptr [bx],88h	;指向MSG3
	call LCD_write_cmd
	lea	bx,LCD_WORD
	lea	si,MSG3
	mov	cx,8
PUTCH:
	mov	ax,[si]
	add	si,2
	mov	word ptr [bx],ax
	call 	LCD_write_word
	loop	PUTCH
	pop		dx
	pop		cx
	pop		ax
	ret
Disp_data endp

;数码管显示速度
led_speed proc	
	push	ax
	push	bx
	push	cx
	push	dx
	lea	bx,led_dat
	mov	al,[bx]
	mov	ah,0
	mov	si,ax
	lea	bx,led_hex
	mov	dx,LED_IO+1
	mov	al,01h		;个位
	out	dx,al
	mov	dx,LED_IO
	mov	al,[si+bx]
	out	dx,al
	pop		dx
	pop		cx
	pop		bx
	pop		ax
	ret
led_speed 	endp

code ends
end start
 