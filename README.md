# VMQ
We installed 128KiB S-RAM outside the Atmel ATmega162.

The circuit diagram and monitor program will be published here.

S-RAM is divided into 4 banks of 32KiB each, and can be mapped to 0x8000-0xffff. The first bank is partly fixedly mapped to 0x2000-0x7fff. By mapping other banks to 0x8000-, you can access up to 56KiB continuously. The first bank can be mapped to 0x8000 - at the same time, so the top 8KiB is also accessible.

The original hexadecimal monitor program was designed by S. Wozniak for his Apple-I computer. We ported this to ATmega162.

Currently, this monitor can only access the RAM address space. However, for R commands, you can jump to a program in the program (Flash) memory space.

These are without warranty without exception.
