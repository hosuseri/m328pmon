#define F_CPU 16000000

#include <avr/io.h>
#include <avr/interrupt.h>
#include "crc.h"

extern void __ctors_end();
extern void init();
extern void monitor();
extern void gecho(const char);
extern void dosleep();

void echo(const char *s);
void memfill();
void memzero();

char read_one = 0;

int main()
{
    init();
    memzero();
    memfill();
    monitor();
    echo("zzz");
    dosleep();
    __ctors_end();
    return 0;
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

    p = (u_char *)0x100;
    for (i=0; i < 0x700; i++) {
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
    p = (u_char *)0x100;
    for (i=0; i < 0x7c0; i++)
	*p++ = c;
}
