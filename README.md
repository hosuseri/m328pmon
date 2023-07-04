# m328pmon
ATmega328P / Arduino UNO Rev.3 monitor

The original Hex Monitor program was designed by S. Wozniak for Apple-I computers. I ported it to ATmega328p.

The 'P' command can be used to change the mode of FLASH. (However, the write target remains SRAM.)
You can return to SRAM mode with the 'S' command.
The 'R' command affects byte addresses (but not word addresses).

You can also access the I2C EEPROM (24LC256) and RTC (8564NB). (experimental)

NO WARRANTIES WITHOUT EXCEPTIONS.