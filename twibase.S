#include <avr/io.h>

	;; TWI(slave) address register
	.equ	addr, 0xfe
	.equ	st_mask, \
		(1<<TWS7)|(1<<TWS6)|\
		(1<<TWS5)|(1<<TWS4)|(1<<TWS3)

	.global twi_init
twi_init:
	in	r0, _SFR_IO_ADDR(SREG)
	;; PC5=SCL, PC4=SDA
	in	r18, _SFR_IO_ADDR(PORTC)
	ori	r18, (1<<PORTC5)|(1<<PORTC4)
	out	_SFR_IO_ADDR(PORTC), r18
	in	r18, _SFR_IO_ADDR(DDRC)
	ori	r18, (1<<DDC5)|(1<<DDC4)
	out	_SFR_IO_ADDR(DDRC), r18
	;; (prescaler value)=1
	ldi	r18, st_mask | ~((1<<TWPS1)|(1<<TWPS0))
	sts	TWSR, r18
	ldi	r18, 12		; 400kHz @16MHz
	sts	TWBR, r18
	ldi	r18, addr //|(1<<TWGCE)
	sts	TWAR, r18
	;; TWAMR=0x00 ;TWI(slave) address mask register
	ldi	r18, 1<<TWEN
	sts	TWCR, r18
	out	_SFR_IO_ADDR(SREG), r0
	ret

	.global twi_start
twi_start:
	in	r0, _SFR_IO_ADDR(SREG)
	ldi	r18, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN)
	sts	TWCR, r18
1:	lds	r18, TWCR
	sbrs	r18, TWINT
	rjmp	1b
	lds	r18, TWSR
	andi	r18, st_mask
	mov	r24, r18
	out	_SFR_IO_ADDR(SREG), r0
	ret

	.global twi_send1
twi_send1:
	in	r0, _SFR_IO_ADDR(SREG)
	sts	TWDR, r24
	ldi	r18, (1<<TWINT)|(1<<TWEN)
	sts	TWCR, r18
1:	lds	r18, TWCR
	sbrs	r18, TWINT
	rjmp	1b
	lds	r18, TWSR
	andi	r18, st_mask
	mov	r24, r18
	out	_SFR_IO_ADDR(SREG), r0
	ret

	.global twi_req
twi_req:
	in	r0, _SFR_IO_ADDR(SREG)
	ldi	r18, (1<<TWINT)|(1<<TWEN)
	sts	TWCR, r18
1:	lds	r18, TWCR
	sbrs	r18, TWINT
	rjmp	1b
	lds	r18, TWSR
	andi	r18, st_mask
	mov	r24, r18
	out	_SFR_IO_ADDR(SREG), r0
	ret

	.global twi_req_wack
twi_req_wack:
	in	r0, _SFR_IO_ADDR(SREG)
	ldi	r18, (1<<TWINT)|(1<<TWEA)|(1<<TWEN)
	sts	TWCR, r18
1:	lds	r18, TWCR
	sbrs	r18, TWINT
	rjmp	1b
	lds	r18, TWSR
	andi	r18, st_mask
	mov	r24, r18
	out	_SFR_IO_ADDR(SREG), r0
	ret

	.global twi_recv
twi_recv:
	in	r0, _SFR_IO_ADDR(SREG)
	lds	r24, TWDR
	out	_SFR_IO_ADDR(SREG), r0
	ret

	.global twi_stop
twi_stop:
	in	r0, _SFR_IO_ADDR(SREG)
	ldi	r18, (1<<TWINT)|(1<<TWSTO)|(1<<TWEN)
	sts	TWCR, r18
1:	lds	r18, TWCR
	sbrc	r18, TWSTO
	rjmp	1b
	lds	r18, TWSR
	andi	r18, st_mask
	mov	r24, r18
	out	_SFR_IO_ADDR(SREG), r0
	ret
