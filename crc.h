#ifndef __CRC_H__
#define __CRC_H__

#include "config.h"
#if HAVE_TYPES_H
#include <sys/types.h>
#else
#include "types.h"
#endif

u_short crc_step(u_char x, u_short acc);

#endif  /* __CRC_H__ */
