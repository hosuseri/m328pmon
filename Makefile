TARGET = vmq

CC = avr-gcc
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump

CFLAGS = -Os -mmcu=atmega328p -Wa,-als
LDFLAGS = -Wl,-Map=$(TARGET).map # -nostartfiles -nodefaultlibs

OBJS = \
	vmq.o \
	crc.o \
	twi.o \
	twibase.o \
	24lc256.o \
	rtc8564nb.o \
	monitor.o

PARTNO = m328p
PORT = /dev/ttyUSB0
PROGRAMMER = arduino

all: $(TARGET).mot list

clean:
	rm -f $(TARGET).mot $(TARGET).elf $(TARGET).lst $(OBJS)

list:  $(TARGET).lst

flash: $(TARGET).mot
	avrdude -c $(PROGRAMMER) -p $(PARTNO) -P $(PORT) \
		-U flash:w:$(TARGET).mot:s

$(TARGET).lst: $(TARGET).elf
	$(OBJDUMP) -d $(TARGET).elf >$(TARGET).lst

$(TARGET).mot: $(TARGET).elf
	$(OBJCOPY) -I elf32-avr -O srec $(TARGET).elf $(TARGET).mot

$(TARGET).elf: $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $(TARGET).elf $(OBJS)

.c.o:
	$(CC) $(CFLAGS) -c $<

.S.o:
	$(CC) $(CFLAGS) -c $<
