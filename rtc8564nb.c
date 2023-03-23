#include "rtc8564nb.h"

void rtc_set_reg(enum rtc_addr addr, u_char val)
{
    twi_sla = 0xa2;
    twi_addr = addr;
    twi_remain = 1;
    twi_data = val;
    twi_rtc_transmit(1);
}

u_char rtc_get_reg(enum rtc_addr addr)
{
    twi_sla = 0xa2;
    twi_addr = addr;
    twi_remain = 1;
    twi_rtc_receive(0);
    return twi_data;
}

u_short twi_rtc_transmit(char writing)
{
    twi_state = twi_s_idle;

L_twi_idle:
    twi_status = twi_start();
    twi_state = twi_s_starting;
    goto L_twi_starting;

L_twi_starting:
    switch (twi_status) {
    case 0x08:
	/**
	 * A START condition has been transmited.
	 */
	twi_status = twi_send1(twi_sla);
	twi_state = twi_s_started;
	goto L_twi_started;

    default:
	break;
    }
    goto L_twi_error;

L_twi_started:
    switch (twi_status) {
    case 0x18:
	/**
	 * SLA+W has been transmitted;
	 * ACK has been received.
	 */
	twi_status = twi_send1((u_char)(twi_addr & 0xff));
	twi_state = twi_s_addr_lo;
	goto L_twi_addr_lo;

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
	break;

    default:
	break;
    }
    goto L_twi_error;

L_twi_addr_lo:
    switch (twi_status) {
    case 0x28:
	/**
	 * Data byte has been transmitted;
	 * ACK has been received.
	 */
	twi_state = twi_s_ready;
	goto L_twi_ready;

    case 0x30:
	/**
	 * Data byte has been transmitted;
	 * NOT ACK has been received.
	 */
	break;

    default:
	break;
    }
    goto L_twi_error;

L_twi_ready:
    switch (twi_status) {
    case 0x28:
	/**
	 * Data byte has been transmitted;
	 * ACK has been received.
	 */
	if (!writing)
	    goto L_twi_complete;

	if (!twi_remain) {
	    twi_state = twi_s_stopping;
	    goto L_twi_stopping;
	}
	twi_status = twi_send1(twi_data);
	--twi_remain;
	twi_addr++;
	twi_state = twi_s_stopping;
	goto L_twi_stopping;

    case 0x30:
	/**
	 * Data byte has been transmitted;
	 * NOT ACK has been received.
	 */
	break;

    default:
	break;
    }
    goto L_twi_error;

L_twi_stopping:
    switch (twi_status) {
    case 0x28:
	/**
	 * Data byte has been transmitted;
	 * ACK has been received.
	 */
	twi_status = twi_stop();
	goto L_twi_complete;

    case 0x30:
	/**
	 * Data byte has been transmitted;
	 * NOT ACK has been received.
	 */
	break;

    default:
	break;
    }
    goto L_twi_error;

L_twi_error:
    twi_status = twi_stop();
    return (u_short)twi_status;

L_twi_complete:
    return (u_short)twi_status;
}

u_short twi_rtc_receive()
{
    twi_state = twi_s_idle;

L_twi_idle:
    twi_rtc_transmit(0);
    /**
     * repeated START
     */
    twi_status = twi_start();
    twi_state = twi_s_starting;
    goto L_twi_starting;

L_twi_starting:
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
	goto L_twi_started;

    default:
	break;
    }
    goto L_twi_error;

L_twi_started:
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
	goto L_twi_ready;

    case 0x48:
	/**
	 * SLA+R has been transmitted;
	 * NOT ACK has been received.
	 */
	break;

    default:
	break;
    }
    goto L_twi_error;

L_twi_ready:
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
	twi_addr++;
	--twi_remain;
	if (twi_remain) {
	    if (twi_remain == 1)
		twi_status = twi_req();
	    else
		twi_status = twi_req_wack();
	    goto L_twi_ready;
	}
	twi_state = twi_s_idle;
	if (!twi_remain) {
	    twi_status = twi_stop();
	    goto L_twi_complete;
	}
	/**
	 * repeated START
	 */
	twi_status = twi_start();
	twi_state = twi_s_starting;
	goto L_twi_starting;

    default:
	break;
    }

L_twi_error:
    twi_status = twi_stop();
    return (u_short)twi_status;

L_twi_complete:
    return (u_short)twi_status;
}
