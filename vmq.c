#define F_CPU 16000000

#include <avr/io.h>
#include <avr/interrupt.h>
#include "crc.h"

enum twi_state_t {
    twi_s_idle,
    twi_s_starting,
    twi_s_started,
    twi_s_addr_hi,
    twi_s_addr_lo,
    twi_s_ready,
    twi_s_stopping,
    twi_s_write,
    twi_s_confirm
};

extern void __ctors_end();
extern void init();
extern void monitor();
extern void twi_init();
extern u_char twi_start();
extern u_char twi_send1(u_char);
extern u_char twi_req();
extern u_char twi_req_wack();
extern u_char twi_recv();
extern u_char twi_stop();
extern void gecho(char);
extern void dosleep();

u_char twi_src0();
void twi_sink0();
u_short twi_transmit(char);
u_short twi_receive();
void echo(const char *);
void memfill();
void memzero();
void phex(u_short, short);

char read_one = 0;
u_char twi_status;
enum twi_state_t twi_state;
u_short twi_addr;
u_short twi_remain;
u_char twi_data;
u_char twi_sla;
u_char (*twi_src)();
void (*twi_sink)();
u_short twi_nerr;
u_short crc;

int main()
{
    u_short i;

    init();
    memzero();
    memfill();
    twi_init();
dbg:
    monitor();
    echo("zzz");
    dosleep();

    for (i=0; i < 1; i++) {
    twi_sla = 0xa0;
    twi_addr = 0x0000;
    twi_remain = 0x8000;
    twi_src = twi_src0;
    twi_transmit(1);

    twi_sla = 0xa0;
    twi_addr = 0x0000;
    twi_remain = 0x8000;
    twi_sink = twi_sink0;
    twi_nerr = 0;
    twi_receive();
    echo("\rtwi_nerr=");
    phex(twi_nerr, 4);
    echo("--\r\n");
    }

    goto dbg;

    //__ctors_end();
    return 0;
}

u_char twi_src0()
{
    register u_short p = twi_addr;
    
    if (!(p & 0x7f)) {
	phex(twi_addr, 4);
	crc = crc_step((u_char)(p & 0xff), 0xffff);
	crc = crc_step((u_char)(p >> 8), crc);
    }
    crc = crc_step((u_char)(p & 0xff), crc);
    return (u_char)(crc & 0xff);
}

void twi_sink0()
{
    register u_short p = twi_addr;

    if (!(p & 0x7f)) {
	phex(p, 4);
	crc = crc_step((u_char)(p & 0xff), 0xffff);
	crc = crc_step((u_char)(p >> 8), crc);
    }
    crc = crc_step((u_char)(p & 0xff), crc);

    if (twi_data != (u_char)(crc & 0xff)) {
	twi_nerr++;
	echo("-*-E-*- ");
	phex(p, 4);
    }
}

u_short twi_transmit(char normal)
{
    twi_state = twi_s_idle;

twi_transit:
    switch (twi_state) {
    case twi_s_idle:
	twi_status = twi_start();
	twi_state = twi_s_starting;
	goto twi_transit;

    case twi_s_starting:
	switch (twi_status) {
	case 0x08:
	    /**
	     * A START condition has been transmited.
	     */
	    twi_status = twi_send1(twi_sla);
	    twi_state = twi_s_started;
	    goto twi_transit;

	default:
	    break;
	}
	goto twi_dbg;

    case twi_s_started:
	switch (twi_status) {
	case 0x18:
	    /**
	     * SLA+W has been transmitted;
	     * ACK has been received.
	     */
	    twi_state = twi_s_addr_hi;
	    goto twi_transit;

	case 0x20:
	    /**
	     * SLA+W has been transmitted;
	     * NOT ACK has been received.
	     */
	    break;

	case 0x38:
	    /**
	     * Arbitration lost in SLA+W or data bytes.
	     */
	    goto twi_dbg;

	default:
	    break;
	}
	goto twi_dbg;

    case twi_s_addr_hi:
	twi_status = twi_send1((u_char)(twi_addr >> 8));
	twi_state = twi_s_addr_lo;
	goto twi_transit;

    case twi_s_addr_lo:
	switch (twi_status) {
	case 0x28:
	    /**
	     * Data byte has been transmitted;
	     * ACK has been received.
	     */
	    twi_status = twi_send1((u_char)(twi_addr & 0xff));
	    twi_state = twi_s_ready;
	    goto twi_transit;

	case 0x30:
	    /**
	     * Data byte has been transmitted;
	     * NOT ACK has been received.
	     */
	    break;

	default:
	    break;
	}
	goto twi_dbg;

    case twi_s_ready:
	switch (twi_status) {
	case 0x28:
	    /**
	     * Data byte has been transmitted;
	     * ACK has been received.
	     */
	    if (!normal)
		break;

	    if (!twi_remain) {
		twi_state = twi_s_stopping;
		goto twi_transit;
	    }
	    twi_data = (*twi_src)();
	    twi_status = twi_send1(twi_data);
	    --twi_remain;
	    twi_addr++;
	    if (!(twi_addr & 0x3f)) {
		twi_state = twi_s_stopping;
		goto twi_transit;
	    }
	    goto twi_transit;

	case 0x30:
	    /**
	     * Data byte has been transmitted;
	     * NOT ACK has been received.
	     */
	    break;

	default:
	    break;
	}
	goto twi_dbg;

    case twi_s_stopping:
	switch (twi_status) {
	case 0x28:
	    /**
	     * Data byte has been transmitted;
	     * ACK has been received.
	     */
	    twi_status = twi_stop();
	    twi_state = twi_s_write;
	    goto twi_transit;

	case 0x30:
	    /**
	     * Data byte has been transmitted;
	     * NOT ACK has been received.
	     */
	    break;

	default:
	    break;
	}
	goto twi_dbg;

    case twi_s_write:
	twi_status = twi_start();
	twi_status = twi_send1(twi_sla);
	twi_state = twi_s_confirm;
	goto twi_transit;

    case twi_s_confirm:
	switch (twi_status) {
	case 0x18:
	    twi_status = twi_stop();
	    twi_state = twi_s_idle;
	    if (!twi_remain)
		break;

	    goto twi_transit;

	default:
	    twi_state = twi_s_write;
	    goto twi_transit;
	}
	break;

    default:
	break;
    }

twi_dbg:
    return (u_short)twi_status;
}

u_short twi_receive()
{
    twi_state = twi_s_idle;

twi_transit:
    switch (twi_state) {
    case twi_s_idle:

	if (!(twi_addr & 0x3f))
	    twi_transmit(0);
	/**
	 * repeated START
	 */
	twi_status = twi_start();
	twi_state = twi_s_starting;
	goto twi_transit;

    case twi_s_starting:
	switch (twi_status) {
	case 0x08:
	    /**
	     * A START condition has been transmited.
	     */
	case 0x10:
	    /**
	     * A repeated START condition has been transmitted.
	     */
	    twi_status = twi_send1(twi_sla|1);
	    twi_state = twi_s_started;
	    goto twi_transit;

	default:
	    break;
	}
	goto twi_dbg;

    case twi_s_started:
	switch (twi_status) {
	case 0x38:
	    /**
	     * Arbitration lost in SLA+R or NOT ACK bit.
	     */
	    break;

	case 0x40:
	    /**
	     * SLA+R has been transmitted;
	     * ACK has been received.
	     */
	    twi_status =
		twi_remain == 1 ? twi_req() : twi_req_wack();
	    twi_state = twi_s_ready;
	    goto twi_transit;

	case 0x48:
	    /**
	     * SLA+R has been transmitted;
	     * NOT ACK has been received.
	     */
	    break;

	default:
	    break;
	}
	goto twi_dbg;

    case twi_s_ready:
	switch (twi_status) {
	case 0x50:
	    /**
	     * Data byte has been received;
	     * ACK has been received.
	     */
	case 0x58:
	    /**
	     * Data byte has been reveived;
	     * NOT ACK has been received.
	     */
	    twi_data = twi_recv();
	    (*twi_sink)(twi_data);
	    twi_addr++;
	    --twi_remain;
	    if (twi_remain && (twi_addr & 0x3f)) {
		if ((twi_addr & 0x3f) == 0x3f || twi_remain == 1)
		    twi_status = twi_req();
		else
		    twi_status = twi_req_wack();
		goto twi_transit;
	    }
	    twi_state = twi_s_idle;
	    if (!twi_remain) {
		twi_status = twi_stop();
		break;
	    }
	    /**
	     * repeated START
	     */
	    twi_status = twi_start();
	    goto twi_transit;

	default:
	    break;
	}
	goto twi_dbg;

    default:
	break;
    }

twi_dbg:
    return (u_short)twi_status;
}

void echo(const char *s)
{
    register const char *p;

    for (p=s; *p; p++) {
	if (!*p)
	    break;
	gecho(*p);
    }
}

void memfill()
{
    register short i;
    register u_short acc, t;
    register u_char c, *p;

    p = (u_char *)0x180;
    for (i=0; i < 0x680; i++) {
	if (!(i & 0x7f)) {
	    t = (u_short)i >> 7;
	    c = (u_char)(t & 0xff);
	    acc = crc_step(c, 0xffff);
	    c = (u_char)(t >> 8);
	    acc = crc_step(c, acc);
	}
	acc = crc_step((u_char)(i & 0x7f), acc);
	*p++ = (u_char)(acc & 0xff);
    }
}

void memzero()
{
    register short i;
    register u_char c, *p;

    c = (u_char)0;
    p = (u_char *)0x180;
    for (i=0; i < 0x740; i++)
	*p++ = c;
}

void phex(u_short val, short len)
{
    char c;

    if (len <= 0) {
	gecho('\r');
	return;
    }
    phex(val >> 4, len - 1);
    c = val & 0xf;
    c = c >= 10 ? c - 10 + 'A' : c + '0';
    gecho(c);
}
