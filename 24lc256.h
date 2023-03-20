#ifndef __24LC256_H__
#define __24LC256_H__

#include "config.h"
#if HAVE_TYPES_H
#include <sys/types.h>
#else
#include "types.h"
#endif

#include "twi.h"

u_short twi_transmit(char normal);
u_short twi_receive();

#endif  /*__24LC256_H__ */
