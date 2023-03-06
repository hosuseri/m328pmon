#include "crc.h"

/*
unsigned char ii[] =
    "\x05\xc8\xeb\xe5\x56\x23\x5e\x23\x05\x28\x1c\xeb\x0e\x80\x1a\xa1"
    "\x28\x01\x37\xed\x6a\x30\x08\x3e\x10\xac\x67\x3e\x21\xad\x6f\xcb"
    "\x09\x30\xeb\x13\x10\xe8\xeb\xe1\x73\x23\x72\xc9";

const int sizeof_ii = sizeof(ii) - 1;
*/

u_short crc_step(u_char x, u_short acc)
{
    int c, k;
    u_char m;

    for (m = 0x80; m; m >>= 1) {
	c = (m & x) != 0;
	k = acc & 0x8000;
	acc <<= 1;
	acc += c;
	if (k)
	    acc ^= 0x1021;
    }
    return acc;
}
