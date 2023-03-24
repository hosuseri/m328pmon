#define F_CPU 16000000

#include <avr/io.h>
#include <avr/interrupt.h>
#include "bio.h"
#include "crc.h"
#include "24lc256.h"
#include "rtc8564nb.h"

void eprom_test();
void rtc_test();
u_char twi_src0();
void twi_sink0();

extern char *charbuf_ptr;
extern char read_one;
u_short crc;

int main()
{
    u_short i;

    init();
    twi_init();
dbg:
    save_ctx();
    monitor();
    bio_echo("zzz");
    dosleep();

    eprom_test();
    rtc_test();

    goto dbg;

    //__ctors_end();
    return 0;
}

void eprom_test()
{
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
    bio_echo("twi_nerr=");
    phex(twi_nerr, 4);
    bio_echo("\n--\n");
}

void rtc_test()
{
    char c, d, *p;
    u_char ss, last_ss;
    u_char mm;
    short i;
    u_short bcd, yyyy;

    rtc_set_reg(rtc_control1, 0x00);
    rtc_set_reg(rtc_control2, 0x00);
    rtc_set_reg(rtc_minute_alarm, 0x00);
    rtc_set_reg(rtc_hour_alarm, 0x00);
    rtc_set_reg(rtc_day_alarm, 0x00);
    rtc_set_reg(rtc_weekday_alarm, 0x00);
    rtc_set_reg(rtc_clkout_freq, 0x00);
    rtc_set_reg(rtc_timer_control, 0x00);
    rtc_set_reg(rtc_timer, 0x00);

show_time:
    bio_putchar('\n');
    last_ss = 0xff;
    while (bio_char_ready())
	bio_getchar();
    for (;; last_ss = ss) {
	if (bio_char_ready())
	    break;

	ss = rtc_get_reg(rtc_seconds) & 0x7f;
	if (ss == last_ss)
	    continue;

	mm = rtc_get_reg(rtc_months);
	yyyy = mm & 0x80 ? 0x2000 : 0x1900;
	mm &= 0x1f;

	bio_putchar('*');
	phex(yyyy | rtc_get_reg(rtc_years), 4);
	bio_putchar('/');
	phex(mm, 2);
	bio_putchar('/');
	phex(rtc_get_reg(rtc_days) & 0x3f, 2);
	bio_putchar(' ');
	phex(rtc_get_reg(rtc_hours) & 0x3f, 2);
	bio_putchar(':');
	phex(rtc_get_reg(rtc_minutes) & 0x7f, 2);
	bio_putchar(':');
	phex(ss, 2);
	bio_putchar('\r');
    }
    while (bio_char_ready())
	bio_getchar();

    bio_echo("\nSET TIME\n");
    bio_gets();
    bio_putchar('\n');
    for (p=charbuf_ptr, i=0; c = *p++; i++)
	if (c < '0' || c > '9')
	    break;

    d = c;
    p = charbuf_ptr;
    mm = 0x80;

    switch (i >> 1) {
    case 7:
	goto L_millenium;
    case 6:
	goto L_year;
    case 5:
	goto L_month;
    case 4:
	goto L_day;
    case 3:
	goto L_hour;
    case 2:
	goto L_minute;
    case 1:
	goto L_second;

    default:
	if (d != 'q' && d != 'Q')
	    goto show_time;
	return;
    }

L_millenium:
    c = *p++;
    bcd = 0;
    bcd |= c - '0';
    c = *p++;
    bcd <<= 4;
    bcd |= c - '0';
    if (bcd < 0x20)
	mm = 0x00;
    

L_year:
    c = *p++;
    bcd = 0;
    bcd |= c - '0';
    c = *p++;
    bcd <<= 4;
    bcd |= c - '0';
    rtc_get_reg(rtc_years);
    rtc_set_reg(rtc_years, bcd);
    ;
L_month:
    c = *p++;
    bcd = 0;
    bcd |= c - '0';
    c = *p++;
    bcd <<= 4;
    bcd |= c - '0';
    rtc_set_reg(rtc_months, mm | bcd & 0x1f);
    ;
L_day:
    c = *p++;
    bcd = 0;
    bcd |= c - '0';
    c = *p++;
    bcd <<= 4;
    bcd |= c - '0';
    rtc_set_reg(rtc_days, bcd & 0x3f);
    ;
L_hour:
    c = *p++;
    bcd = 0;
    bcd |= c - '0';
    c = *p++;
    bcd <<= 4;
    bcd |= c - '0';
    rtc_set_reg(rtc_hours, bcd & 0x3f);
    ;
L_minute:
    c = *p++;
    bcd = 0;
    bcd |= c - '0';
    c = *p++;
    bcd <<= 4;
    bcd |= c - '0';
    rtc_set_reg(rtc_minutes, bcd & 0x7f);
    ;
L_second:
    c = *p++;
    bcd = 0;
    bcd |= c - '0';
    c = *p++;
    bcd <<= 4;
    bcd |= c - '0';
    rtc_set_reg(rtc_seconds, bcd & 0x7f);
    ;

    goto show_time;
}

u_char twi_src0()
{
    register u_short p = twi_addr;
    
    if (!(p & 0x7f)) {
	phex(twi_addr, 4);
	bio_putchar('\n');
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
	bio_putchar('\n');
	crc = crc_step((u_char)(p & 0xff), 0xffff);
	crc = crc_step((u_char)(p >> 8), crc);
    }
    crc = crc_step((u_char)(p & 0xff), crc);

    if (twi_data != (u_char)(crc & 0xff)) {
	twi_nerr++;
	bio_echo("-*-E-*- ");
	phex(p, 4);
	bio_putchar('\n');
    }
}
