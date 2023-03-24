#ifndef __BIO_H__
#define __BIO_H__

#include "config.h"
#if HAVE_TYPES_H
#include <sys/types.h>
#else
#include "types.h"
#endif

void __ctors_end();
void init();
void monitor();
void dosleep();
void phex(u_short, char);
void bio_putchar(char);
void raw_putchar(char);
void bio_echo(const char *);
volatile char bio_char_ready();
volatile char bio_getchar();
void bio_gets();
void save_ctx();

extern char *charbuf_ptr;

#endif  /*__BIO_H__ */
