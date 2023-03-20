#define F_CPU 16000000

#include <avr/io.h>
#include <avr/interrupt.h>
#include "crc.h"
#include "24lc256.h"

extern void __ctors_end();
extern void init();
extern void monitor();
extern void gecho(char);
extern void dosleep();

u_char twi_src0();
void twi_sink0();
void echo(const char *);
void memfill();
void memzero();
void phex(u_short, short);

char read_one = 0;
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
