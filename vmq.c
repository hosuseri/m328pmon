#define F_CPU 16000000

#include <avr/io.h>

extern void monitor();
extern void gecho(const char);

void echo(const char *s);

static const char bye[] = "\r*BYE*\r";

int main()
{
    monitor();
    echo(bye);
    return 0;
}

void echo(const char *s)
{
    register const char *p;

    for (p=bye; *p;)
	gecho(*p++);
}
