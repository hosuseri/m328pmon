TARGET = vmq

CC = avr-gcc
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump

CFLAGS = -Os -mmcu=atmega162 -Wa,-als
LDFLAGS = -Wl,-Map=$(TARGET).map

OBJS = \
	vmq.o \
	monitor.o

PARTNO = m162
PORT = usb:39:34
PROGRAMMER = atmelice_isp

all: $(TARGET).mot list

clean:
	rm -f $(TARGET).mot $(TARGET).elf $(TARGET).lst $(OBJS)

list:  $(TARGET).lst

flash: $(TARGET).mot
	avrdude -c $(PROGRAMMER) -p $(PARTNO) -P $(PORT) -e \
		-U flash:w:$(TARGET).mot

fuse:
	avrdude -c $(PROGRAMMER) -p $(PARTNO) -P $(PORT) -u \
		-U efuse:w:0xff:m \
		-U hfuse:w:0xd1:m \
		-U lfuse:w:0x9f:m

$(TARGET).lst: $(TARGET).elf
	$(OBJDUMP) -d $(TARGET).elf >$(TARGET).lst

$(TARGET).mot: $(TARGET).elf
	$(OBJCOPY) -I elf32-avr -O srec $(TARGET).elf $(TARGET).mot

$(TARGET).elf: $(OBJS)
	$(CC) $(CFLAGS) -o $(TARGET).elf $(OBJS)

.c.o:
	$(CC) $(CFLAGS) -c $<

.S.o:
	$(CC) $(CFLAGS) -c $<
