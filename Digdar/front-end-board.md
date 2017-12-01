## A Front-end Board for Radar Digitizers ##

For the four standard marine radar signals:

 - video (VID)
 - trigger (TRG)
 - azimuth count pulse (ACP)
 - azimuth return pulse (ARP)

we'd like a simple black box to condition these signals for feeding
into at least these possible radar digitizers:

 - red pitaya (RP)
 - USRP

The mapping of radar outputs to digitizer inputs needs to allow for matching:
 - DC voltage bias
 - input/output impedance matching
 - peak to peak voltage range

## RP Back End ##

Although TRG, ACP, and ARP are sometimes fed into a Schmitt-trigger fronted
single-bit input, a more flexible approach is to explicitly digitize each
signal at an appropriate rate and bit-depth, then perform edge detection
in the digital domain.

Here's how we currently handle the signals on the RP (all pins have DC input-coupling):

 signal|bandwidth|RP pin|digitizer input|radar output
 ---|---|---|---|---
 VID|30 MHz or higher|ADC0, 14 bit, 125 MSPS|-1 to +1 V; 1 MΩ 10pF|-0.5 to +3V; 50 or 75 Ω
 TRG|30 MHz or higher|ADC0, 14 bit, 125 MSPS|-13 to +13 V; 1 MΩ 10pF|0 to +12V; unknown Ω
 ACP|5 kHz or higher|AUXADCA, 12 bit, 25 KSPS|0 to 3.5 V; unknown Ω|0 to +12V; unknown Ω
 ARP|5 kHz or higher|AUXADCB, 12 bit, 25 KSPS|0 to 3.5 V; unknown Ω|0 to +12V; unknown Ω

## Current RP Front End ##

VID and TRG have a 50 Ω termination added to match cabling and SMA connectors.
All 4 signals are fed through custom, simple discrete-component resistor networks to
match voltage ranges and impedances.   We want to replace all of this with

## Desired Front End ##

We want a box with 4 x 50 Ω BNC inputs and 4 x 50 Ω BNC outputs, one pair for
each radar signal.  The board should perform impedance matching, DC biasing,
and gain/attenuation independently on each line.  A microcontroller on the board
should accept commands over a USB interface to set and report the
conditioning parameters on each signal line.  It's probably easiest to have
commands and responses sent over a USB control endpoint.

The box should be powered from the USB connection to the host computer.
