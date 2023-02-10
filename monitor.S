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
	.equ charbuf, 0x0200	; low 8bits are ignored (fixed to 0x00)

	.text

	.global USART_RX_vect
USART_RX_vect:
	out	_SFR_IO_ADDR(SMCR), r1
	push	r0
	lds	r0, UDR0
	sts	read_one, r0
	pop	r0
	reti

	.global init
init:
	cli
	ldi	r18, 1<<IVCE
	sts	MCUCR, r18
	sts	MCUCR, r1
	sei
	ret
	
	.global monitor
monitor:
	push	r28
	push	r29
	//eor	r1, r1
	ldi	r18, lo8(baud_rate)
	sts	UBRR0L, r18
	ldi	r18, hi8(baud_rate)
	sts	UBRR0H, r18
	ldi	r18, (1<<RXCIE0)|(1<<RXEN0)|(1<<TXEN0)
	sts	UCSR0B, r18
	ldi	r18, (1<<USBS0)|(3<<UCSZ00)
	sts	UCSR0C, r18
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
	lds	r18, read_one
	sts	read_one, r1
	sei
	or	r18, r18
	brne	1f
	ldi	r18, 1<<SE
	out	_SFR_IO_ADDR(SMCR), r18
	sleep
	out	_SFR_IO_ADDR(SMCR), r1
	rjmp	nextchar	; Loop until ready.
1:
	rcall	toupr

	st	y, r18		; Add to text buffer
	rcall	echo		; Display char.
	cpi	r18, 0x0d	; CR?
	brne	notcr		; No.
	ldi	r28, 0xff	; Reset text index.
	mov	r18, r1		; For XAM mode.
setstor:
setmode:			; upon entry, XAM Mode Set
	mov	MODE, r18	; 0x00=XAM, 0x3a=STOR, 0x2e=BLOCK XAM.
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
	breq	escape		; Yes, generate ESC sequence
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
	or	MODE, MODE
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
	ld	r18, z		; Get data byte at 'examine index'
	rcall	prbyte		; Output it in hex format
xamnext:
	mov	MODE, r1	; 0 -> MODE (XAM mode).
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
	ret

toupr:
	cpi	r18, 'a'
	brcs	1f
	cpi	r18, 'f' + 1
	brcc	1f
	subi	r18, 'a' - 'A'
1:	ret

	.global gecho
gecho:
	mov	r18, r24
	rjmp	echo

	.end
