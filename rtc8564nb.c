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

u_short twi_rtc_transmit(char normal)
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
	    twi_status = twi_send1((u_char)(twi_addr & 0xff));
	    twi_state = twi_s_addr_lo;
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

    case twi_s_addr_lo:
	switch (twi_status) {
	case 0x28:
	    /**
	     * Data byte has been transmitted;
	     * ACK has been received.
	     */
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
	    twi_status = twi_send1(twi_data);
	    --twi_remain;
	    twi_addr++;
	    twi_state = twi_s_stopping;
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
	    goto twi_dbg;

	    /**/
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

u_short twi_rtc_receive()
{
    twi_state = twi_s_idle;

twi_transit:
    switch (twi_state) {
    case twi_s_idle:

	twi_rtc_transmit(0);
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
	    twi_addr++;
	    --twi_remain;
	    if (twi_remain) {
		if (twi_remain == 1)
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
