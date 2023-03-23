#ifndef __RTC8564NB_H__
#define __RTC8564NB_H__

#include "config.h"
#if HAVE_TYPES_H
#include <sys/types.h>
#else
#include "types.h"
#endif

#include "twi.h"

enum rtc_addr {
    rtc_control1 = 0x00,
    rtc_control2 = 0x01,
    rtc_seconds  = 0x02,
    rtc_minutes  = 0x03,
    rtc_hours    = 0x04,
    rtc_days     = 0x05,
    rtc_weekdays = 0x06,
    rtc_months   = 0x07,
    rtc_years    = 0x08,
    rtc_minute_alarm  = 0x09,
    rtc_hour_alarm    = 0x0a,
    rtc_day_alarm     = 0x0b,
    rtc_weekday_alarm = 0x0c,
    rtc_clkout_freq   = 0x0d,
    rtc_timer_control = 0x0e,
    rtc_timer         = 0x0f
};

void rtc_set_reg(enum rtc_addr addr, u_char val);
u_char rtc_get_reg(enum rtc_addr addr);

u_short twi_rtc_transmit(char normal);
u_short twi_rtc_receive();

#endif  /* __RTC8564NB_H__ */
