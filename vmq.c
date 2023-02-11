#define F_CPU 16000000

#include <avr/io.h>
#include <avr/interrupt.h>

extern void __ctors_end();
extern void init();
extern void monitor();
extern void gecho(const char);
extern void dosleep();

void echo(const char *s);

char read_one = 0;

int main()
{
    init();
    monitor();
    echo("zzz");
    dosleep();
    __ctors_end();
    return 0;
}

void echo(const char *s)
{
    register const char *p;

    for (p=s; *p; p++) {
	if (!*p)
	    break;
	gecho(*p);
    }
}
