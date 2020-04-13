.model small
.386
IO_8255 equ 200h
IO_8254	equ	210h
AD_IO	equ	220h
LED_IO	equ	230h

data segment
	stepper 	db 	01H,03H,02H,06H,04H,0CH,08H,09H	;����ʱ��
	speed		db	50								;��������ٶ�
	dir			db	0								;�����������
	step_now	db 	0								;ָʾ��ǰ��һ��ʱ��
	AD_result	db	0								;ADת����������
	led_hex		db	3fh,06h,5bh,4fh,66h,6dh,7dh,07h,7fh,6Fh;�����0-9��������
	led_dat		db	0								;����ܽ�Ҫ��ʾ����ֵ
	delayms 	db 	0								;��ʱ��׼��
	LCD_CMD		db 	0								;��12864д�������
	LCD_DAT		db 	0								;��12864д�������
	LCD_WORD	dw 	0								;��LCDд������ı���
	PTA_temp	db 	0								;�ݴ�8255PA�ڵ�ǰ�����
	MSG1		dw	0B2BDh,0BDF8h,0B5E7h,0BBFAh,0A1AAh,0B3A3h,0BAA3h,0D3B1h	;�������-����ӱ
	MSG2		dw	0B0A0h,0B5E7h,0D7D4h,0A3B1h,0A3B7h,0A3B0h,0A3B4h,0B0E0h	;����1704��
	MSG3		dw	0B0A0h,0B7BDh,0CFF2h,0A1FAh,0CBD9h,0B6C8h,0A3B0h,0B0A0h	;MSG3+6����0A1FAh MSG3+12�ٶ�
	MSG4		dw	0D6B8h,0B5BCh,0BDCCh,0CAA6h,0A1AAh,0D0BBh,0C0CFh,0CAA6h	;ָ����ʦ-л��ʦ
data ends

ss_ssg	segment
	dw	50 dup(0)
ss_ssg	ends

code segment
	assume cs:code,ds:data,ss:ss_ssg
START:
	cli							;���ж�
	mov ax,data
	mov	ds,ax
;8255��ʼ��
	mov	dx,IO_8255+3		;8255���ƿ�
	mov	al,82H	   			;10000010bA��� B����
	out	dx,al

;lcd��ʼ��
	lea	bx,LCD_CMD
	mov byte ptr [bx],0Ch	;����ʾ
	call LCD_write_cmd
	mov	ax,1
	call Disp_line			;��ʾ��һ��
	mov	ax,2	
	call Disp_line			;��ʾ�ڶ���
	mov	ax,3				
	call Disp_line			;��ʾ������
	mov	ax,4
	call Disp_line			;��ʾ������

;step_now init
	lea	bx,step_now
	mov	byte ptr [bx],0

;8254��ʼ��
	mov	dx,IO_8254+3		;8254 control 213h
	mov al,01110111b		;CNT1 BCD���� 16bit ��ʽ3(����)
	out dx,al
	mov dx,IO_8254+1		;CNT1 ,211h
	mov al,0				;10000��Ƶ,�õ�100Hz
	out dx,al
	out dx,al				;BCD0
	mov dx,IO_8254+3		;213h
	mov al,10110110b		;CNT2 �����Ƽ��� 16bit ��ʽ3
	out dx,al
	mov dx,IO_8254+2		;CNT2,212h
	mov ax,20;200			;20��Ƶ,�õ�5Hz
	out dx,al
	mov al,ah
	out dx,al	
;CLK1-1MHz,OUT1-100Hz-CLK2,OUT2-0.5Hz
	
	;�����ж�������
	;��Ƭ
	in	al,21h
	and	al,11011011b		;MIR5(AD) MIR2(SIR0)
	out	21h,al
	;��Ƭ
	in	al,0a1h
	and al,11111110b		;SIR0
	out	0a1h,al
	;�����ж�������
	push	ds
	mov	ax,0
	mov	ds,ax
	lea	ax,cs:PIT_IRQ_HANDLER	;AXָ���жϳ�����ڵ�ַ�����붨ʱ�ж�
	mov	si,70h					;�ж�������,SIR0
	add	si,si
	add	si,si
	mov	ds:[si],ax				;�ж�������IP
	push	cs
	pop		ax
	mov	ds:[si+2],ax			;�ж�������CS
	;AD
	mov	ax,0
	mov	ds,ax
	lea	ax,cs:AD_IRQ_HANDLER	;AXָ���жϳ�����ڵ�ַ
	mov	si,35h					;IRQ5(MIR5)
	add	si,si
	add	si,si
	mov	ds:[si],ax			;�ж�������IP
	push	cs
	pop		ax
	mov	ds:[si+2],ax			;�ж�������CS
	pop		ds
	call 	AD_START
	sti								;���ж�
	
RUN:
	call 	delay					;��ʱ50ms
	call 	step
	call 	Disp_data
	call	led_speed
	jmp 	RUN
	

;AD�ж�
AD_IRQ_HANDLER proc	far	
	push	ax
	push	dx
	mov dx,AD_IO			;��AD
	inc dx
	in 	al,dx				;����ADֵ
	lea	bx,ad_result
	mov	[bx],al
	mov	al,20h				;�����жϽ�������EOI
	out	20h,al
	pop		dx
	pop		ax
	sti
	iret
AD_IRQ_HANDLER endp


;��ʱ�жϷ����ӳ���
PIT_IRQ_HANDLER proc far
	push	ax
	push	dx				;�����ֳ�
	call	read_switch		;��ȡ�ٶȷ���
	lea	bx,dir				;���·�����Ϣ
	mov al,[bx]
	lea	bx,MSG3
	cmp	al,0
	jz	LEFT
	mov	word ptr [bx+6],0A1FBh	;��
	jmp	RIGHT
LEFT:	
	mov	word ptr [bx+6],0A1FAh	;��
RIGHT:
	mov	al,20h			;�����жϽ�������SIR0
	out	0a0h,al
	mov	al,20h			;�����жϽ�������MIR2(SIR0)
	out	20h,al
	call 	AD_START
	pop		dx
	pop		ax
	sti
	iret
PIT_IRQ_HANDLER endp	

;�ٶȶ�ȡ����
read_switch proc
	push	ax
	push	bx
	push	cx
	push	dx
	mov	dx,IO_8255+1		;��B��
	in	al,dx
	and	al,80h				;B7��dir 10000000bȡ���λ��Ϊ����
	
	lea	bx,dir
	mov	[bx],al

	lea	bx,ad_result
	mov	al,[bx]				;ȡad_result
	shr al,1
	shr al,1		
	shr al,1		;����8 0-31
	add	al,5			;ȡֵ5-36
	lea	bx,speed		;��λ������		
	mov	[bx],al	
	dec	al
	shr	al,1
	shr	al,1			;����4
	mov	ah,9
	sub	ah,al
	mov	al,ah			;alȡֵ1-8
	mov	ah,0
	lea bx,led_dat		;�������ֵ
	mov	[bx],al
	lea	bx,MSG3
	add	ax,0A3B0h
	mov	[bx+12],ax		;+12���޸��ٶ�
	pop		dx
	pop		cx
	pop		bx
	pop		ax
	ret
read_switch endp



;����ADת��
AD_START	proc	
	mov dx,AD_IO
	out dx,al
	ret
AD_START	endp

;��ʱ,ͨ��speedֵ�ı���������֮����ʱʱ��,���ڲ�������ٶ�
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


;��������������
step	proc	
	push 	ax
	push 	bx
	push 	dx
	mov	ax,0
	lea	bx,step_now
	mov	al,byte ptr [bx]
	mov	si,ax
	cmp	dir,0		;����
	jz	FORWARD		;=0
	dec	si
	JMP OUTPUT_STEP
FORWARD:
	inc si
OUTPUT_STEP:
	cmp si,0
	JNL	NOT_MIN		;>=,��תѭ��
	mov	si,7
NOT_MIN:
	cmp	si,7
	JLE	NOT_MAX		;<=,��תѭ��
	mov	si,0
NOT_MAX:
	mov	dx,IO_8255
	lea bx,stepper
	mov	al,[bx+si]	;���һ������
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
	mov	dx,IO_8255;�ٶȹ������������
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
	mov	dx,IO_8255;�ٶȹ������������
	mov	al,PTA_temp
	out dx,al
	pop		dx
	pop		bx
	pop		ax
	ret
step	endp

;�������ʾ�ٶ�
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
	mov	al,01h		;��λ
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

;LCD��ʾ��N��
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
	mov byte ptr [bx],80h	;ָ���һ��
	call LCD_write_cmd
	lea	si,MSG1
	jmp	DISP
LINE2:
	mov byte ptr [bx],90h	;ָ��ڶ���
	call LCD_write_cmd
	lea	si,MSG2
	jmp	DISP
LINE3:
	mov byte ptr [bx],88h	;ָ�������
	call LCD_write_cmd
	lea	si,MSG3
	jmp	DISP
LINE4:
	mov byte ptr [bx],98h	;ָ�������
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


;LCDд������ӳ���
;д��LCD_CMD��ָ��
LCD_write_cmd proc	
	push	ax
	push	bx
	push	dx
	lea	bx,LCD_CMD
	mov	al,[bx]
	mov	dx,IO_8255+2	
	out	dx,al					;PTC���
	mov	dx,IO_8255
	lea bx,PTA_temp
	mov	al,[bx]
	and	al,00011111b			;A6A7��0,д����I,W
	out	dx,al
	or	al,10000000b			;E=1 ��ʹ��
	out	dx,al
	lea	bx,delayms
	mov	byte ptr [bx],1  		;��ʱ1ms
	call LCD_delay
	and	al,01111111b			;E=0
	out	dx,al
	pop		dx
	pop		bx
	pop		ax
	ret
LCD_write_cmd 	endp

;д��LCD_DAT����	
LCD_write_data proc	
	push	ax
	push	bx
	push	dx
	lea	bx,LCD_DAT
	mov	al,[bx]
	mov	dx,IO_8255+2	
	out dx,al					;PTC���
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

;д��LCD_DAT����	
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

;LCD��ʱ������д������֮��	
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
	mov byte ptr [bx],88h	;ָ��MSG3
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

;�������ʾ�ٶ�
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
	mov	al,01h		;��λ
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
 