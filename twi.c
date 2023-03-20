#include "twi.h"

u_char twi_status;
enum twi_state_t twi_state;
u_short twi_addr;
u_short twi_remain;
u_char twi_data;
u_char twi_sla;
u_char (*twi_src)();
void (*twi_sink)();
u_short twi_nerr;
