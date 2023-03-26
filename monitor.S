/* APPLE COMPUTER 6502 HEX MONITOR
 * ORIGINALLY WRITTEN BY S.Wozniak
 * PORTED TO ATmega328p BY T.Tsukamoto
 */
#include <avr/io.h>

#define MODE	r22
#define YSAV	r23
#define L	r24
#define H	r25
#define STL	r26
#define STH	r27
#define XAML	r30
#define XAMH	r31

	.equ baud_rate, 25	; 38.4kbps @16MHz
	.equ charbuf, 0x0100	; low 8bits are ignored (fixed to 0x00)

	.equ x_r0,   0
	.equ x_r1,   1
	.equ x_r2,   2
	.equ x_r3,   3
	.equ x_r4,   4
	.equ x_r5,   5
	.equ x_r6,   6
	.equ x_r7,   7
	.equ x_r8,   8
	.equ x_r9,   9
	.equ x_r10, 10
	.equ x_r11, 11
	.equ x_r12, 12
	.equ x_r13, 13
	.equ x_r14, 14
	.equ x_r15, 15
	.equ x_r16, 16
	.equ x_r17, 17
	.equ x_r18, 18
	.equ x_r19, 19
	.equ x_r20, 20
	.equ x_r21, 21
	.equ x_r22, 22
	.equ x_r23, 23
	.equ x_r24, 24
	.equ x_r25, 25
	.equ x_r26, 26
	.equ x_r27, 27
	.equ x_r28, 28
	.equ x_r29, 29
	.equ x_r30, 30
	.equ x_r31, 31
	.equ x_spl, 32
	.equ x_sph, 33
	.equ x_pcl, 34
	.equ x_pch, 35
	.equ x_sreg,36
	.equ ctx_siz, 37


	.data
	
	.org	charbuf
	.ds.b	0x80
	
	.global charbuf_ptr
charbuf_ptr:
	.dc.w	charbuf
	
	.equ	cq_size, 16
cq_core:
	.ds.b	cq_size

cq_head:
	.dc.w	cq_core

cq_tail:
	.dc.w	cq_core

ctx0:	.ds.b	ctx_siz

	.global cur_ctx
cur_ctx:
	.dc.w	ctx0


	.text

	.global USART_RX_vect
USART_RX_vect:
	push	r18
	in	r18, _SFR_IO_ADDR(SREG)
	push	r18
	push	r26
	push	r27
	out	_SFR_IO_ADDR(SMCR), r1
	lds	r26, cq_tail
	lds	r27, cq_tail+1
	lds	r18, UDR0
	st	X+, r18
	cpi	r26, lo8(cq_core+cq_size)
	ldi	r18, hi8(cq_core+cq_size)
	cpc	r27, r18
	brcs	1f
	ldi	r26, lo8(cq_core)
	ldi	r27, hi8(cq_core)
1:	sts	cq_tail, r26
	sts	cq_tail+1, r27
	pop	r27
	pop	r26
	pop	r18
	out	_SFR_IO_ADDR(SREG), r18
	pop	r18
	reti

	.global dosleep
dosleep:
	cbi	_SFR_IO_ADDR(PORTB), PORTB5
	ldi	r18, 1<<SE
	out	_SFR_IO_ADDR(SMCR), r18
	sei
	nop
	sleep
	out	_SFR_IO_ADDR(SMCR), r1
	sbi	_SFR_IO_ADDR(PORTB), PORTB5
	ret

	.global init
init:
	cli
	ldi	r18, 1<<IVCE
	sts	MCUCR, r18
	sts	MCUCR, r1

	sbi	_SFR_IO_ADDR(DDRB), DDB5
	sbi	_SFR_IO_ADDR(PORTB), PORTB5

	ldi	r18, lo8(baud_rate)
	sts	UBRR0L, r18
	ldi	r18, hi8(baud_rate)
	sts	UBRR0H, r18
	ldi	r18, (1<<RXCIE0)|(1<<RXEN0)|(1<<TXEN0)
	sts	UCSR0B, r18
	ldi	r18, (1<<USBS0)|(3<<UCSZ00)
	sts	UCSR0C, r18

	sei
	ret
	
	.global monitor
monitor:
	push	r28
	push	r29
	;; 
	call	show_regs
	;;
	mov	MODE, r1	; SRAM Mode
	;; 
	ldi	r28, 0x7f
	ldi	r29, hi8(charbuf)
	mov	r18, r1		; set ZERO.
notcr:	cpi	r18, 0x08	; Backspace ?
	breq	backspace
	cpi	r18, 0x1b	; ESC?
	breq	escape		; Yes
	inc	r28		; Advance text index.
	brpl	nextchar	; Auto ESC if > 127.
escape:	ldi	r18, 0x5c	; '\'
	rcall	echo		; Output it.
getline:
	ldi	r18, 0x0d	; CR
	rcall	echo		; Output it.
	ldi	r28, 0x01	; Init text index
backspace:
	dec	r28		; Back up text index.
	brmi	getline		; Beyond start of line, reinitialize.
nextchar:
	push	r24
	push	r26
	push	r27
	call	bio_getchar
	mov	r18, r24
	pop	r27
	pop	r26
	pop	r24

	cpi	r18, 0x1b	; ESC?
	breq	escape		; Yes
	
	rcall	toupr

	st	y, r18		; Add to text buffer
	rcall	echo		; Display char.
	cpi	r18, 0x0d	; CR?
	brne	notcr		; No.
	ldi	r28, 0xff	; Reset text index.
	mov	r18, r1
	andi	MODE, 0x80	; For XAM mode.
setstor:
setmode:			; upon entry, XAM Mode Set
	eor	MODE, r18	; 0x00=XAM, 0x3a=STOR, 0x2e=BLOCK XAM.
				; 0x21=FLASH XAM.
blkskip:
	inc	r28		; Advance text index.
nextitem:
	ld	r18, y		; Get char.
	cpi	r18, 0x0d	; CR?
	breq	getline		; Yes, done this line.
	cpi	r18, 0x2e	; '.'?
	brlo	blkskip		; Skip delimiter.
	breq	setmode		; Set BLOCK XAM mode.
	cpi	r18, 0x3a	; ':'?
	breq	setstor		; Yes, set STOR mode
	cpi	r18, 0x52	; 'R'?
	breq	run		; Yes, run user program.
	cpi	r18, 'P'
	brne	1f
	ldi	MODE, 0x80
	mov	r18, r1
	rjmp	setmode
1:	cpi	r18, 'S'
	brne	2f
	mov	MODE, r1
	mov	r18, r1
	rjmp	setmode
2:	cpi	r18, 'Q'
	brne	3f
	rjmp	retc
3:	cpi	r18, 'Z'
	brne	4f
	rjmp	zzz_sleep
4:	
	mov	L, r1		; 0x00 -> L
	mov	H, r1		;  and H.
	mov	YSAV, r28	; Save Y for comparison.
nexthex:
	ld	r18, y		; Get char. for hex test.
	ldi	r19, 0x30
	eor	r18, r19	; Map digits to 0-9
	cpi	r18, 0x0a	; Digit ?
	brlo	dig		; Yes.
	ldi	r19, 0x89
	add	r18, r19	; Map letter 'A'-'F' to 0xfa-ff.
	;; 'A' = 0x41; 0x41 .eor. 0x30 = 0x71; 0x71 + 0x89 = 0xfa
	;; 'F' = 0x46; 0x46 .eor. 0x30 = 0x76; 0x76 + 0x89 = 0xff
	cpi	r18, 0xfa	; Hex letter ?
	brlo	nothex		; No, char not hex.
dig:	lsl	r18		; Hex digit to MSD of r18.
	lsl	r18
	lsl	r18
	lsl	r18
	ldi	r19, 0x04	; Shift count.
hexshift:
	lsl	r18		; Hex dig left, MSB to carry.
	rol	L		; Rotate into LSD.
	rol	H		; Rotate into MSD's.
	dec	r19		; Done 4 shifts ?
	brne	hexshift	; No, loop.
	inc	r28		; Advance text index
	rjmp	nexthex		; Always taken. Check next char for hex.
nothex:	cp	r28, YSAV	; Check if L, H empty (no hex digits).
	//breq	escape		; Yes, generate ESC sequence
	brne	1f
	rjmp	escape
1:
	mov	r18, MODE	; Test MODE byte
	andi	r18, 0x10
	breq	notstor		; b4=1 for STOR, 0 for XAM and BLOCK XAM
	st	x+, L		; LSD's of hex data.
tonextitem:
	rjmp	nextitem	; Get next command item.
run:	lsr	r31
	ror	r30
	ijmp			; Run at current XAM index
notstor:
	mov	r18, MODE
	andi	r18, 0x7f
	brne	xamnext		; MODE=0 for XAM, MODE=0x2e for BLOCK XAM.
	mov	STL, L		; Copy hex data to
	mov	STH, H		;  'store index'
	mov	XAML, L		; And to 'XAM index'.
	mov	XAMH, H
	eor	r1, r1		; Set Z flag.
nxtprnt:
	brne	prdata		; NE means no address to print
	ldi	r18, 0x0d	; CR.
	rcall	echo		; Output it.
	mov	r18, XAMH	; 'Examine index' high-order byte.
	rcall	prbyte		; Output it in hex format.
	mov	r18, XAML	; Low order 'examine index' byte.
	rcall	prbyte		; Output it in hex format.
	ldi	r18, 0x3a	; ':'
	rcall	echo		; Output it.
prdata:	ldi	r18, 0x20	; Blank.
	rcall	echo		; Output it.
	bst	MODE, 7
	brts	1f
	ld	r18, z		; Get data byte at 'examine index'
	rjmp	2f
1:	lpm	r18, z
2:	rcall	prbyte		; Output it in hex format
xamnext:
	andi	MODE, 0x80	; 0 -> MODE (XAM mode).
	mov	r18, XAML
	cp	r18, L		; Compare 'examine index' to hex data.
	mov	r18, XAMH
	sbc	r18, H
	brsh	tonextitem	; Not less so no more data to output
	inc	XAML
	brne	mod8chk		; Increment 'examine index'.
	inc	XAMH
mod8chk:
	mov	r18, XAML	; Check low-order 'examine index byte.
	andi	r18, 0x07	;   for MOD 8 = 0.
	rjmp	nxtprnt		; Always taken.
prbyte:	mov	r21, r18	; Save r18 for LSD.
	lsr	r18		; MSD to LSD position.
	lsr	r18
	lsr	r18
	lsr	r18
	rcall	prhex		; Output hex digit.
	mov	r18, r21	; restore r18.
prhex:	andi	r18, 0x0f	; Mask LSD for hex print.
	ori	r18, 0x30	; Add '0'.
	cpi	r18, 0x3a	; Digit ?
	brlo	echo		; Yes, output it.
	ldi	r19, 0x7
	add	r18, r19	; Add offset for letter.
echo:	mov	r20, r18	; Save CR.
1:	lds	r0, UCSR0A	; Write ready ?
	sbrs	r0, UDRE0
	rjmp	1b		; No, wait for display.
	sts	UDR0, r18	; Output character.
	cpi	r18, 0x0d	; CR?
	brne	2f		; No.
	ldi	r18, 0x0a	; LF
	rcall	1b		; Output it.
2:	mov	r18, r20	; Restore CR.
	ret
	;;
retc:	pop	r29
	pop	r28
	jmp	restore_ctx
	;;
zzz_sleep:
	ldi	r24, lo8(zzz)
	ldi	r25, hi8(zzz)
	call	pm_puts
	call	dosleep
	call	eprom_test
	call	rtc_test
	rjmp	retc

toupr:
	cpi	r18, 'a'
	brcs	1f
	cpi	r18, 'z' + 1
	brcc	1f
	subi	r18, 'a' - 'A'
1:	ret

	.global phex
phex:
	push	r0
	in	r0, _SFR_IO_ADDR(SREG)
	push	r0
	push	r18
	push	r19
	push	r22
	push	r23
	push	r24
	movw	r18, r24
	ldi	r23, 4
	sub	r23, r22
	breq	2f
1:	lsl	r18
	rol	r19
	lsl	r18
	rol	r19
	lsl	r18
	rol	r19
	lsl	r18
	rol	r19
	dec	r23
	brne	1b
2:	mov	r24, r1
	lsl	r18
	rol	r19
	rol	r24
	lsl	r18
	rol	r19
	rol	r24
	lsl	r18
	rol	r19
	rol	r24
	lsl	r18
	rol	r19
	rol	r24
	cpi	r24, 10
	brlo	3f
	subi	r24, 10
	ldi	r23, 'A'
	add	r24, r23
	rjmp	4f
3:	ldi	r23, 0x30
	add	r24, r23
4:	push	r18
	rcall	bio_putchar
	pop	r18
	dec	r22
	brne	2b
	pop	r24
	pop	r23
	pop	r22
	pop	r19
	pop	r18
	pop	r0
	out	_SFR_IO_ADDR(SREG), r0
	pop	r0
	ret

	.global bio_putchar
bio_putchar:
	push	r0
	in	r0, _SFR_IO_ADDR(SREG)
	push	r0
	push	r18
	push	r24
	cpi	r24, '\n'
	brne	1f
	mov	r18, r24
	ldi	r24, '\r'
	rcall	2f
	mov	r24, r18
1:	rcall	2f
	pop	r24
	pop	r18
	pop	r0
	out	_SFR_IO_ADDR(SREG), r0
	pop	r0
	ret
2:	lds	r0, UCSR0A	; Write ready ?
	sbrs	r0, UDRE0
	rjmp	2b		; No, wait for display.
	sts	UDR0, r24	; Output character.
	ret

	.global raw_putchar
raw_putchar:
	push	r0
	in	r0, _SFR_IO_ADDR(SREG)
	push	r0
	rcall	2b
	pop	r0
	out	_SFR_IO_ADDR(SREG), r0
	pop	r0
	ret

	.global bio_echo
bio_echo:
	in	r0, _SFR_IO_ADDR(SREG)
	push	r0
	movw	r26, r24
1:	ld	r24, X+
	or	r24, r24
	brne	2f
	pop	r0
	out	_SFR_IO_ADDR(SREG), r0
	ret
2:	rcall	bio_putchar
	rjmp	1b

	.global bio_char_ready
bio_char_ready:
	mov	r24, r1
	cli
	lds	r18, cq_head
	lds	r19, cq_head+1
	lds	r20, cq_tail
	lds	r21, cq_tail+1
	sei
	cp	r18, r20
	cpc	r19, r21
	breq	1f
	inc	r24
1:	ret

	.global bio_getchar
bio_getchar:
1:	rcall	bio_char_ready
	or	r24, r24
	brne	2f
	
	cbi	_SFR_IO_ADDR(PORTB), PORTB5
	
	ldi	r18, 1<<SE
	out	_SFR_IO_ADDR(SMCR), r18
	sleep
	out	_SFR_IO_ADDR(SMCR), r1
	
	sbi	_SFR_IO_ADDR(PORTB), PORTB5

	rjmp	1b

2:	cli
	lds	r26, cq_head
	lds	r27, cq_head+1
	sei
	ld	r24, X+
	cpi	r26, lo8(cq_core+cq_size)
	ldi	r18, hi8(cq_core+cq_size)
	cpc	r27, r18
	brcs	3f
	ldi	r26, lo8(cq_core)
	ldi	r27, hi8(cq_core)
3:	cli
	sts	cq_head, r26
	sts	cq_head+1, r27
	sei
	ret

	.global bio_gets
bio_gets:
	ldi	r26, lo8(charbuf)
	ldi	r27, hi8(charbuf)
	ldi	r18, 127
1:	push	r18
	push	r26
	push	r27
	rcall	bio_getchar
	pop	r27
	pop	r26
	pop	r18
	cpi	r24, '\r'
	breq	2f
	st	X+, r24
	rcall	bio_putchar
	dec	r18
	brne	1b
2:	st	X+, r1
	ret

	.global save_ctx
save_ctx:
	push	r28
	push	r29
	lds	r28, cur_ctx
	lds	r29, cur_ctx + 1
	std	Y + x_r30, r30
	std	Y + x_r31, r31
	movw	r30, r28
	pop	r29
	pop	r28
	std	Z + x_r0, r0
	in	r0, _SFR_IO_ADDR(SREG)
	std	Z + x_sreg, r0
	std	Z + x_r1, r1
	std	Z + x_r2, r2
	std	Z + x_r3, r3
	std	Z + x_r4, r4
	std	Z + x_r5, r5
	std	Z + x_r6, r6
	std	Z + x_r7, r7
	std	Z + x_r8, r8
	std	Z + x_r9, r9
	std	Z + x_r10, r10
	std	Z + x_r11, r11
	std	Z + x_r12, r12
	std	Z + x_r13, r13
	std	Z + x_r14, r14
	std	Z + x_r15, r15
	std	Z + x_r16, r16
	std	Z + x_r17, r17
	std	Z + x_r18, r18
	std	Z + x_r19, r19
	std	Z + x_r20, r20
	std	Z + x_r21, r21
	std	Z + x_r22, r22
	std	Z + x_r23, r23
	std	Z + x_r24, r24
	std	Z + x_r25, r25
	std	Z + x_r26, r26
	std	Z + x_r27, r27
	std	Z + x_r28, r28
	std	Z + x_r29, r29
	pop	r19
	std	Z + x_pch, r19
	pop	r18
	std	Z + x_pcl, r18
	in	r0, _SFR_IO_ADDR(SPL)
	std	Z + x_spl, r0
	in	r0, _SFR_IO_ADDR(SPH)
	std	Z + x_sph, r0
	movw	r30, r18
	ijmp

	.global restore_ctx
restore_ctx:
	pop	r0
	pop	r0
	lds	r30, cur_ctx
	lds	r31, cur_ctx + 1
	ldd	r1, Z + x_r1
	ldd	r2, Z + x_r2
	ldd	r3, Z + x_r3
	ldd	r4, Z + x_r4
	ldd	r5, Z + x_r5
	ldd	r6, Z + x_r6
	ldd	r7, Z + x_r7
	ldd	r8, Z + x_r8
	ldd	r9, Z + x_r9
	ldd	r10, Z + x_r10
	ldd	r11, Z + x_r11
	ldd	r12, Z + x_r12
	ldd	r13, Z + x_r13
	ldd	r14, Z + x_r14
	ldd	r15, Z + x_r15
	ldd	r16, Z + x_r16
	ldd	r17, Z + x_r17
	ldd	r18, Z + x_r18
	ldd	r19, Z + x_r19
	ldd	r20, Z + x_r20
	ldd	r21, Z + x_r21
	ldd	r22, Z + x_r22
	ldd	r23, Z + x_r23
	ldd	r24, Z + x_r24
	ldd	r25, Z + x_r25
	ldd	r26, Z + x_r26
	ldd	r27, Z + x_r27
	ldd	r28, Z + x_r28
	ldd	r29, Z + x_r29
	ldd	r0, Z + x_spl
	out	_SFR_IO_ADDR(SPL), r0
	ldd	r0, Z + x_sph
	out	_SFR_IO_ADDR(SPH), r0
	ldd	r0, Z + x_sreg
	out	_SFR_IO_ADDR(SREG), r0
	ldd	r0, Z + x_pcl
	push	r0
	ldd	r0, Z + x_pch
	push	r0
	ldd	r0, Z + x_r0
	push	r28
	push	r29
	movw	r28, r30
	ldd	r30, Y + x_r30
	ldd	r31, Y + x_r31
	pop	r29
	pop	r28
	ret

show_regs:
	push	r28
	push	r29
	lds	r28, cur_ctx
	lds	r29, cur_ctx + 1
	ldi	r24, '\n'
	call	bio_putchar
	;;
	ldi	r24, lo8(L_r0)
	ldi	r25, hi8(L_r0)
	call	pm_puts
	ldd	r24, Y + x_r0
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r1)
	ldi	r25, hi8(L_r1)
	call	pm_puts
	ldd	r24, Y + x_r1
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r2)
	ldi	r25, hi8(L_r2)
	call	pm_puts
	ldd	r24, Y + x_r2
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r3)
	ldi	r25, hi8(L_r3)
	call	pm_puts
	ldd	r24, Y + x_r3
	ldi	r22, 2
	call	phex
	
	ldi	r24, '\n'
	call	bio_putchar

	;;
	ldi	r24, lo8(L_r4)
	ldi	r25, hi8(L_r4)
	call	pm_puts
	ldd	r24, Y + x_r4
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r5)
	ldi	r25, hi8(L_r5)
	call	pm_puts
	ldd	r24, Y + x_r5
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r6)
	ldi	r25, hi8(L_r6)
	call	pm_puts
	ldd	r24, Y + x_r6
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r7)
	ldi	r25, hi8(L_r7)
	call	pm_puts
	ldd	r24, Y + x_r7
	ldi	r22, 2
	call	phex
	
	ldi	r24, '\n'
	call	bio_putchar

	;;
	ldi	r24, lo8(L_r8)
	ldi	r25, hi8(L_r8)
	call	pm_puts
	ldd	r24, Y + x_r8
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r9)
	ldi	r25, hi8(L_r9)
	call	pm_puts
	ldd	r24, Y + x_r9
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r10)
	ldi	r25, hi8(L_r10)
	call	pm_puts
	ldd	r24, Y + x_r10
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r11)
	ldi	r25, hi8(L_r11)
	call	pm_puts
	ldd	r24, Y + x_r11
	ldi	r22, 2
	call	phex
	
	ldi	r24, '\n'
	call	bio_putchar

	;;
	ldi	r24, lo8(L_r12)
	ldi	r25, hi8(L_r12)
	call	pm_puts
	ldd	r24, Y + x_r12
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r13)
	ldi	r25, hi8(L_r13)
	call	pm_puts
	ldd	r24, Y + x_r13
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r14)
	ldi	r25, hi8(L_r14)
	call	pm_puts
	ldd	r24, Y + x_r14
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r15)
	ldi	r25, hi8(L_r15)
	call	pm_puts
	ldd	r24, Y + x_r15
	ldi	r22, 2
	call	phex
	
	ldi	r24, '\n'
	call	bio_putchar

	;;
	ldi	r24, lo8(L_r16)
	ldi	r25, hi8(L_r16)
	call	pm_puts
	ldd	r24, Y + x_r16
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r17)
	ldi	r25, hi8(L_r17)
	call	pm_puts
	ldd	r24, Y + x_r17
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r18)
	ldi	r25, hi8(L_r18)
	call	pm_puts
	ldd	r24, Y + x_r18
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r19)
	ldi	r25, hi8(L_r19)
	call	pm_puts
	ldd	r24, Y + x_r19
	ldi	r22, 2
	call	phex
	
	ldi	r24, '\n'
	call	bio_putchar

	;;
	ldi	r24, lo8(L_r20)
	ldi	r25, hi8(L_r20)
	call	pm_puts
	ldd	r24, Y + x_r20
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r21)
	ldi	r25, hi8(L_r21)
	call	pm_puts
	ldd	r24, Y + x_r21
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r22)
	ldi	r25, hi8(L_r22)
	call	pm_puts
	ldd	r24, Y + x_r22
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r23)
	ldi	r25, hi8(L_r23)
	call	pm_puts
	ldd	r24, Y + x_r23
	ldi	r22, 2
	call	phex
	
	ldi	r24, '\n'
	call	bio_putchar

	;;
	ldi	r24, lo8(L_r24)
	ldi	r25, hi8(L_r24)
	call	pm_puts
	ldd	r24, Y + x_r24
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r25)
	ldi	r25, hi8(L_r25)
	call	pm_puts
	ldd	r24, Y + x_r25
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r26)
	ldi	r25, hi8(L_r26)
	call	pm_puts
	ldd	r24, Y + x_r26
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r27)
	ldi	r25, hi8(L_r27)
	call	pm_puts
	ldd	r24, Y + x_r27
	ldi	r22, 2
	call	phex
	
	ldi	r24, '\n'
	call	bio_putchar

	;;
	ldi	r24, lo8(L_r28)
	ldi	r25, hi8(L_r28)
	call	pm_puts
	ldd	r24, Y + x_r28
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r29)
	ldi	r25, hi8(L_r29)
	call	pm_puts
	ldd	r24, Y + x_r29
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	
	ldi	r24, lo8(L_r30)
	ldi	r25, hi8(L_r30)
	call	pm_puts
	ldd	r24, Y + x_r30
	ldi	r22, 2
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts

	ldi	r24, lo8(L_r31)
	ldi	r25, hi8(L_r31)
	call	pm_puts
	ldd	r24, Y + x_r31
	ldi	r22, 2
	call	phex
	
	ldi	r24, '\n'
	call	bio_putchar
	;;
	ldi	r24, lo8(L_sreg)
	ldi	r25, hi8(L_sreg)
	call	pm_puts
	ldd	r24, Y + x_sreg
	ldi	r22, 2
	call	phex
	
	ldi	r24, '\n'
	call	bio_putchar
	;;
	ldi	r24, lo8(L_sp)
	ldi	r25, hi8(L_sp)
	call	pm_puts
	ldd	r24, Y + x_spl
	ldd	r25, Y + x_sph
	ldi	r22, 4
	call	phex
	ldi	r24, lo8(L_sr_sep)
	ldi	r25, hi8(L_sr_sep)
	call	pm_puts
	;;
	ldi	r24, lo8(L_pc)
	ldi	r25, hi8(L_pc)
	call	pm_puts
	ldd	r24, Y + x_pcl
	ldd	r25, Y + x_pch
	ldi	r22, 4
	call	phex

	ldi	r24, '('
	call	bio_putchar

	ldd	r24, Y + x_pcl
	ldd	r25, Y + x_pch
	lsl	r24
	rol	r25
	ldi	r22, 4
	call	phex

	ldi	r24, ')'
	call	bio_putchar

	ldi	r24, '\n'
	call	bio_putchar

	pop	r29
	pop	r28
	ret

	.global pm_puts
pm_puts:
	movw	r30, r24
1:	lpm	r24, Z+
	or	r24, r24
	breq	2f
	call	bio_putchar
	rjmp	1b
2:	ret

L_r0:	.asciz "R0 ="
L_r1:	.asciz "R1 ="
L_r2:	.asciz "R2 ="
L_r3:	.asciz "R3 ="
L_r4:	.asciz "R4 ="
L_r5:	.asciz "R5 ="
L_r6:	.asciz "R6 ="
L_r7:	.asciz "R7 ="
L_r8:	.asciz "R8 ="
L_r9:	.asciz "R9 ="
L_r10:	.asciz "R10="
L_r11:	.asciz "R11="
L_r12:	.asciz "R12="
L_r13:	.asciz "R13="
L_r14:	.asciz "R14="
L_r15:	.asciz "R15="
L_r16:	.asciz "R16="
L_r17:	.asciz "R17="
L_r18:	.asciz "R18="
L_r19:	.asciz "R19="
L_r20:	.asciz "R20="
L_r21:	.asciz "R21="
L_r22:	.asciz "R22="
L_r23:	.asciz "R23="
L_r24:	.asciz "R24="
L_r25:	.asciz "R25="
L_r26:	.asciz "R26="
L_r27:	.asciz "R27="
L_r28:	.asciz "R28="
L_r29:	.asciz "R29="
L_r30:	.asciz "R30="
L_r31:	.asciz "R31="
L_sreg:	.asciz "SREG="
L_sp:	.asciz "SP="
L_pc:	.asciz "PC="
L_sr_sep:
	.asciz ", "

zzz:	.asciz "zzz"

	.end
