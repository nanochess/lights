	;
	; Follow the lights
	;
	; by Oscar Toledo G.
	;
	; Creation date: Jan/16/2020.
	; Revision date: Jan/17/2020.
	;    Added victory tune after 31 good lights.
	;

	;
	; Very useful info gathered from:
	; https://www.waitingforfriday.com/?p=586
	;
	cpu 8086

    %ifdef com_file
	org 0x0100
    %else
	org 0x7c00
    %endif

old_time:	equ 0x00	; Old ticks
button:		equ 0x02	; Button pressed
next_seq:	equ 0x04	; Next seq. number
timing:		equ 0x06	; Current timing
memory:		equ 0x08	; Start of memory
memory_end:	equ 0x28	; End of memory

start:
	xor ax,ax
	mov cx,memory_end/2
.0:
	push ax		; Zero word initialize
	loop .0		; Repeat until completed

	mov al,0x02	; Text mode 80x25
	int 0x10	; Set up video mode

	mov bp,sp	; Setup BP (Base Pointer)

	in al,0x40	; Get a pseudorandom number
	xchg ax,si	; Put into SI

	cld		; Clear Direction flag.
	mov ax,0xb800	; Point to video segment
	mov ds,ax
	mov es,ax

	call show_buttons	; Show buttons
restart_game:
	xor ax,ax	; Restart sequence
	mov [bp+next_seq],ax
game_loop:
	mov cl,15	; Wait 0.8 seconds.
	call wait_ticks

	;
	; Add a new light to sequence
	;
	mov di,[bp+next_seq]	; Curr. position.

	mov ax,97	; Generate random number
	mul si
	add ax,23
	xchg ax,si	; SI = next seed.

			; Notice it uses the
			; high byte because the
			; random period is
			; longer.

	and ah,0x03	; Extract random from AH
	add ah,0x31	; Add ASCII 1
	mov [bp+di+memory],ah	; Save into memory

	mov ax,8	; 8 approx 0.42 secs.
	cmp di,5	; For 5 or fewer lights.
	jb .2
	mov al,6	; 6 approx 0.32 secs.
	cmp di,13	; For 13 or fewer lights.
	jb .2
	mov al,4	; 4 approx 0.22 secs.
.2:
	mov [bp+timing],ax
	cmp di,31	; Doing the 31st light?
	je victory	; Yes, jump to victory.
	inc byte [bp+next_seq]

	;
	; Show current sequence
	;
	xor di,di	; Restart counter
.1:	mov al,[bp+di+memory]	; Read light
	push di
	mov [bp+button],al	; Push button
	call show_buttons	; Show
	mov cx,[bp+timing]	; Wait
	call wait_ticks
	call speaker_off	; Turn off

	mov byte [bp+button],0
	call show_buttons	; Depress button
	call wait_tick
	pop di
	inc di		; Increase counter
	cmp di,[bp+next_seq]
	jne .1

	;
	; Empty keyboard buffer
	;
.9:
	mov ah,0x01	; Check for key pressed.
	int 0x16
	je .8		; No, jump.
	mov ah,0x00	; Read key.
	int 0x16
	jmp .9		; Repeat loop
.8:
	;
	; Comparison of player input with
	; sequence.
	;
	xor di,di	; Restart counter
.4:	mov ah,0x00	; Wait for a key
	int 0x16
	cmp al,0x1b	; Esc pressed?
	je exit_game	; Yes, jump.
	cmp al,0x31	; Less than ASCII 1?
	jb .4		; Yes, jump.
	cmp al,0x35	; Higher than ASCII 4?
	jnb .4		; Yes, jump.
	push ax
	push di
	mov [bp+button],al	; Push button
	call show_buttons	; Show
	mov cx,[bp+timing]	; Wait
	call wait_ticks
	call speaker_off	; Turn off

	mov byte [bp+button],0
	call show_buttons	; Depress button
	call wait_tick
	pop di
	pop ax
	cmp al,[bp+di+memory]	; Good hit?
	jne wrong		; No, jump
	
	inc di		; Increase counter
	cmp di,[bp+next_seq]
	jne .4
	jmp game_loop

	;
	; Player defeat by wrong button
	;
wrong:	mov cx,28409	; 1193180 / 42
	call speaker	; Failure tone
	mov cl,27	; 1.5 secs
	call wait_ticks
	call speaker_off	; Turn off
	mov cl,27	; 1.5 secs
	call wait_ticks
	jmp restart_game	; Restart game

	;
	; Victory
	;
victory:
	mov al,'2'	; Victory tune
	mov cx,14	; 14 notes
.1:	push cx
	push ax
	mov byte [bp+button],al
	call show_buttons	; Play
	mov cl,2	; Wait 0.1 secs.
	call wait_ticks
	mov byte [bp+button],0	; Depress
	call show_buttons
	pop ax
	inc ax		; Next note
	cmp al,'5'	; If goes to 5...
	jne .2
	mov al,'1'	; ...go back to 1.
.2:
	pop cx
	loop .1
	jmp wrong	; Finish and restart

	;
	; Exit game
	;
exit_game:
	mov ax,0x0002	; Clear screen by...
	int 0x10	; ...mode setup.
	int 0x20	; Exit to DOS / bootOS.

	;
	; Show game buttons
	;
show_buttons:
	mov di,0x0166	; Top left on screen
	mov bx,0x312f	; ASCII 1, white on green
	mov cx,2873	; 1193180 / 415.305 hz
	call show_button

	mov di,0x0192	; Top right on screen
	mov bx,0x324f	; ASCII 2, white on red
	mov cx,3835	; 1193180 / 311.127 hz
	call show_button

	mov di,0x0846	; Bottom left on screen
	mov bx,0x336f	; ASCII 3, white on brown
	mov cx,4812	; 1193180 / 247.942 hz
	call show_button

	mov di,0x0872	; Bottom right on screen
	mov bx,0x343f	; ASCII 4, white on turquoise
	mov cx,5746	; 1193180 / 207.652 hz

	; Fall-through

show_button:
	mov al,0x20	; Fill with spaces
	cmp bh,[bp+button]	; Is it pressed?
	jne .0		; No, jump.
	call speaker	; Yes, play sound.
	mov al,0xb0	; Semi-filled block
.0:
	mov cx,10	; 10 rows high.
.1:	push cx
	mov ah,bl	; Set attribute byte.
	mov cl,20	; 20 columns width.
	rep stosw	; Fill on screen
	add di,160-20*2		; Go to next row
	pop cx
	loop .1		; Repeat until filled
	mov al,bh	; Get button number
	mov [di+20-5*160],ax	; Put on center
	ret		; Return

	;
	; Wait for one tick
	;
wait_tick:
	mov cl,1

	;
	; Wait for several ticks
	;
	; Input:
	; CL = Number of ticks
	;
wait_ticks:
	mov ch,0
.0:
	push cx		; Save counter
.1:
	mov ah,0x00	; Read ticks
	int 0x1a	; Call BIOS
	cmp dx,[bp+old_time]	; Wait for tick change
	je .1
	mov [bp+old_time],dx	; Save new tick
	pop cx		; Restore counter
	loop .0		; Loop until complete
	ret		; Return

	;
	; Generate sound on PC speaker
	;
	; Input:
	; CX = Frequency value.
	;      (calculate 1193180/freq = req. value)
	;
speaker:
	mov al,0xb6	; Setup timer 2
	out 0x43,al
	mov al,cl	; Low byte of timer count
	out 0x42,al
	mov al,ch	; High byte of timer count
	out 0x42,al
	in al,0x61
	or al,0x03	; Wire PC speaker to timer 2
	out 0x61,al
	ret

	;
	; Turn speaker off
	;
speaker_off:
	in al,0x61
	and al,0xfc	; Turn off
	out 0x61,al
	ret

	;
	; Boot sector signature
	;
    %ifdef com_file
    %else
	times 510-($-$$) db 0x4f
	db 0x55,0xaa	; Make it a bootable sector
    %endif

