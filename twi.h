#ifndef __TWI_H__
#define __TWI_H__

#include "config.h"
#if HAVE_TYPES_H
#include <sys/types.h>
#else
#include "types.h"
#endif

enum twi_state_t {
    twi_s_idle = 0,
    twi_s_starting,
    twi_s_started,
    twi_s_addr_hi,
    twi_s_addr_lo,
    twi_s_ready,
    twi_s_stopping,
    twi_s_write,
    twi_s_confirm
};

void twi_init();
u_char twi_start();
u_char twi_send1(u_char);
u_char twi_req();
u_char twi_req_wack();
u_char twi_recv();
u_char twi_stop();

extern u_char twi_status;
extern enum twi_state_t twi_state;
extern u_short twi_addr;
extern u_short twi_remain;
extern u_char twi_data;
extern u_char twi_sla;
extern u_char (*twi_src)();
extern void (*twi_sink)();
extern u_short twi_nerr;

#endif  /* __TWI_H__ */
