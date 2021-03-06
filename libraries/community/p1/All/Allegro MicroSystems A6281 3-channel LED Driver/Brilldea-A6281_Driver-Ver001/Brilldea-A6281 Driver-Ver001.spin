''**************************************
''
''  Brilldea's Allegro A6281 Driver Ver. 00.1
''
''  Timothy D. Swieter, E.I.
''  Brilldea - purveyor of prototyping goods
''  www.brilldea.com
''
''  Copyright (c) 2009 Timothy D. Swieter, E.I.
''  See end of file for terms of use.
''
''  Updated: April 11, 2009
''
''Description:
''
''      This is a driver for the Allegro MicroSystems A6281 three channel LED controller.
''      The driver is an assembly language driver and requires one cog to be used.
''      See the demo code for examples on how to setup the driver and use it.
''
''
''Reference:
''      Allegro MicroSystems A6281 data sheet
''      Brilldea PolkaDOT-51 schematic and data sheet
''
''To do:
''      - Verify the timing of ci to li is working properly under bufferconfiguration
''
''Revision Notes:
'' 0.1  Start of coding
''
''**************************************
CON               'Constants to be located here
'***************************************                       

  '***************************************
  ' System Definitions     
  '***************************************

  _OUTPUT       = 1             'Sets pin to output in DIRA register
  _INPUT        = 0             'Sets pin to input in DIRA register  
  _HIGH         = 1             'High=ON=1=3.3v DC
  _ON           = 1
  _LOW          = 0             'Low=OFF=0=0v DC
  _OFF          = 0
  _ENABLE       = 1             'Enable (turn on) function/mode
  _DISABLE      = 0             'Disable (turn off) function/mode

  '***************************************
  ' A6281 ASM Command Definitions (commands to ASM routine)
  '***************************************
  _BufferSetup  = 1 << 16       'Set the buffer location and pixel count
  _EnableChain  = 2 << 16       'Enable/disable the A6281 OEI
  _UpdateChain  = 3 << 16       'Send the buffer out to the chain
  _BlankChain   = 4 << 16       'Send all zeros to the A6281
  _LastByte     = 5 << 16       

  '***************************************
  ' A6281 Driver Flag Definitions
  '***************************************

  _Flag_ASMrunning = |< 1       'Flag to indicated asm routine is started succesfully

  '***************************************
  ' A6281 Definitions
  '***************************************

  Ctr0Shift = 0 * 10            'Shift left this many times for PWM Counter0
  Ctr1Shift = 1 * 10            'Shift left this many times for PWM Counter1
  Ctr2Shift = 2 * 10            'Shift left this many times for PWM Counter2

  Ctr0Mask = $3FF << Ctr0Shift  '10 bits in the lower portion of a long for PWM counter 0
  Ctr1Mask = $3FF << Ctr1Shift  '10 bits in the middle portion of a long for PWM counter 1
  Ctr2Mask = $3FF << Ctr2Shift  '10 bits in the upper portion of a long for PWM counter 2

  DotCor0Mask = $7F << Ctr0Shift '7 bits in the lower postion of a long for Dot Correction Register 0
  DotCor1Mask = $7F << Ctr1Shift '7 bits in the middle postion of a long for Dot Correction Register 1
  DotCor2Mask = $7F << Ctr2Shift '7 bits in the upper postion of a long for Dot Correction Register 2

  ClkModeMask = $180            '2 bits in the lower position of a long for the clock mode register

  AddressMask = |< 30           '1 bit in the 30th location for the address mask - data vs config
  
  '***************************************
  ' Misc Definitions
  '***************************************  

  'nada

'**************************************
VAR               'Variables to be located here
'***************************************

  'processor overhead
  long  A6281Cog                'Cog flag/ID
  long  A6281flags              'Flags for the A6281 Driver COG

  'Command setup
  long  command                 'stores command and arguments for the ASM driver

  'I/O pins (placed here so they can be passed to the ASM routine)
  long  A6281_ClockIn           'Clock into the A6281 (CI), Propeller output and A6281 input
                                'Serial clock input; PWM clock if external clock is selected
  long  A6281_SerialDataIn      'Serial data into the A6281 (SDI), Propeller output and A6281 input
                                'Serial data input to shift register
  long  A6281_LatchIn           'Latch into the A6281 (LI), Propeller output and A6281 input
                                'Latch input terminal; serial data is latched with high-level input
  long  A6281_OutputEnableIn    'Output Enable into the A6281 (OEI), Propeller output and A6281 input
                                'Output enable input, when low (active), the output drivers are enabled; when high (inactive),
                                'all output drivers are turned off (blanked)

  long pixelsperchain           'Number of pixels in a chain

'***************************************
OBJ               'Object declaration to be located here
'***************************************

  'nada

'***************************************
PUB start(_CI, _SDI, _LI, _OEI) : Okay
'***************************************
'' Starts the A6281 LED Driver cog which consumes 1 cog.
'' The A6281Cog can only have one instance of it running.

  'Keeps from two cogs running
  stop      

  'Initialize the I/O (puts it into variables for access by the ASM routine)
  A6281_ClockIn := _CI
  A6281_SerialDataIn := _SDI
  A6281_LatchIn := _LI
  A6281_OutputEnableIn := _OEI

  'Clear the command buffer - be sure no commands were set before initializing
  command := 0

  'Start a cog to execute the ASM routine
  okay := A6281Cog := cognew(@Entry, @command) + 1

  'Initialize and set a flag if cog started succesfully
  if okay
    A6281flags := _Flag_ASMrunning

  return
  
'***************************************
PUB stop                        
'***************************************
'' Stop the A6281 LED Driver control cog if one is running
'' only a single ccog can be running at a time.
'' This routine will free a cog.

  if A6281Cog                                           'Is cog non-zero?
    cogstop(A6281Cog~ - 1)                              'Yes, stop the cog and then make value zero
    A6281flags := 0                                     'Clear the flags
    
  return

'***************************************
PUB BufferConfiguration(_a, _b, _c) | t
'***************************************
'' This command configures the A6281 driver with a pointer
'' to the LED pixel buffer, the number of pixels in the
'' the buffer and the delay time for the latch setup
'' when clocking the data out.
''
'' _a := the buffer starting location, i.e. _a := @buffer[0]
'' _b := the number of pixels in the buffer (the number of longs)
'' _c := set to zero, value calculated below based on _b

  _a := _a + 4 *_b                                      'Calculate the end of the buffer and use that in processing in the ASM routine

  t := clkfreq / 1_000_000_000                          'Calculate 1ns
  _c := (20 * t) + (_b * (5 * t))                       'Calculate the setup time for CI to LI

  pixelsperchain := _b                                  'Save the value for use elsewhere
  
  if (A6281flags & _Flag_ASMrunning)
    'Send the command
    command := _BufferSetup + @_a

    'wait for the command to complete (at the end of x number of packets)
    repeat while command

  return

'***************************************
PUB OutputEnable(_a) 
'***************************************
'' This command enables/disables the OEI of the A6281.
'' Note this command doesn't permanently keep the OEI in the state,
'' as updating the chain with data will still work and restore the
'' the OEI to the proper state to display data.
''
'' This command is mainly used for testing and advanced control purposes.
''
'' _a := true to show data, false to disable the outputs

  if (A6281flags & _Flag_ASMrunning)
    'Send the command
    command := _EnableChain + @_a

    'wait for the command to complete (at the end of x number of packets)
    repeat while command

  return

'***************************************
PUB Update           
'***************************************
'' This command sends the latest data in the buffer to a chain
'' of A6281s.  The buffer data can be either config data or display
'' data.  This command updates the display once and immediately returns to
'' the calling program so the two can working parallel.  Just be sure to not
'' change the buffer - best for double buffered animation.

  if (A6281flags & _Flag_ASMrunning)
    'Send the command
    command := _UpdateChain

    'wait for the command to complete (at the end of x number of packets)
    'repeat while command

  return
  
'***************************************
PUB Updateandhold    
'***************************************
'' This command sends the latest data in the buffer to a chain
'' of A6281s.  The buffer data can be either config data or display
'' data.  This command updates the display once and pauses the calling
'' programs execution while the update is performed.  This should be used
'' for single buffer animations.

  if (A6281flags & _Flag_ASMrunning)
    'Send the command
    command := _UpdateChain

    'wait for the command to complete (at the end of x number of packets)
    repeat while command

  return

'***************************************
PUB Clear            
'***************************************
'' This command sends all zeros to the A6281 chain which
'' causes all the display data to be cleared (not the config data).

  if (A6281flags & _Flag_ASMrunning)
    'Send the command
    command := _BlankChain

    'wait for the command to complete (at the end of x number of packets)
    repeat while command

  return

'***************************************
PUB setPixel(_buffer, _pixel, _Rint, _Gint, _Bint) | templong
'***************************************
'' Set a particular pixel (in the buffer) to the RGB value
'' For the PolkaDOT-51 the PWM Counter 0 is blue
'' For the PolkaDOT-51 the PWM Counter 1 is red
'' For the PolkaDOT-51 the PWM Counter 2 is green
''
'' _buffer = the buffer starting address, i.e. _buffer := @pixelbuffer[0]
'' _pixel = the pixel to be updated
'' _Rint, _Gint, Bint = the intensity value of the channel

  'Check the bounds of the intensity value
  _Rint <#= 1023
  _Rint #>= 0

  _Gint <#= 1023
  _Gint #>= 0

  _Bint <#= 1023
  _Bint #>= 0

  'Check the bounds of the pixel value
  _pixel <#= pixelsperchain
  _pixel #>= 0

  'Build the pixel long
  templong := (_Gint << Ctr2Shift) | (_Rint << Ctr1Shift) | (_Bint << Ctr0Shift)

  'Store the long in the correct buffer location
  long[_buffer + (4 * _pixel)] := templong

  return

'***************************************
PUB updatePixels(_OnScrnBuffer, _OffScrnBuffer, _size, _clearoffscreen, waitforfinish)
'***************************************
'' For double buffer animation copy the offscreen buffer
'' to the onscreen buffer and then update the chain without
'' pausing for the update - i.e. get back to calculating
'' the next update.

  longmove(_OnScrnBuffer, _OffScrnBuffer, _size)

  if waitforfinish
    Updateandhold
  else
    Update

  if _clearoffscreen
    ClearBuffer(_OffScrnBuffer, _size)

  return

'***************************************
PUB ClearBuffer(_buffer, _size)
'***************************************
'' Clear the buffer - zero it out

  longfill(_buffer, 0, _size)

  return  

'***************************************
DAT
'***************************************
''  Assembly language driver for controling an A6281 LED Driver

        org
'-----------------------------------------------------------------------------------------------------
'Start of assembly routine
'-----------------------------------------------------------------------------------------------------
Entry         mov       t0,     par             'Load address of command into t0 (par contains the address of the command)

              'Bring over the data for the pin and create the mask'
              add       t0,     #4              'Increment the address pointer by 4 bytes (skip over the command + parameter address)
              rdlong    ciPin,  t0              'Read value of A6281_ClockIn
              mov       ciMask, #1              'Load the mask with a 1
              shl       ciMask, ciPin           'Create the mask for the proper I/O pin by shifting the 1

              add       t0,     #4              'Increment the address pointer by 4 bytes
              rdlong    sdiPin, t0              'Read value of A6281_SerialDataIn
              mov       sdiMask,#1              'Load the mask with a 1
              shl       sdiMask,sdiPin          'Create the mask for the proper I/O pin by shifting the 1

              add       t0,     #4              'Increment the address pointer by 4 bytes
              rdlong    liPin,  t0              'Read value of A6281_LatchIn
              mov       liMask, #1              'Load the mask with a 1
              shl       liMask, liPin           'Create the mask for the proper I/O pin by shifting the 1

              add       t0,     #4              'Increment the address pointer by 4 bytes
              rdlong    oeiPin, t0              'Read value of A6281_OutputEnableIn
              mov       oeiMask,#1              'Load the mask with a 1
              shl       oeiMask,oeiPin          'Create the mask for the proper I/O pin by shifting the 1

              'Set the initial state of the I/O, unless listed here, the output is initialized as off
              mov       outa,   oeiMask         'A6281 outputs are intialized off

              'Next set up the I/O with the masks and the direction register
              'all I/O pins are set to output here.
              mov       dira,   ciMask          'Set to an output and clears cog dira register
              or        dira,   sdiMask         'Set to an output
              or        dira,   liMask          'Set to an output
              or        dira,   oeiMask         'Set to an output

'----------------------------------------------------------------------------------------------------- 
'Main loop
'wait for a command to come in, then process it.  In between command processing send the data packets
'-----------------------------------------------------------------------------------------------------
CmdWait
'             test      periodicfg,$FF     wz   'Check if the flag is clear
'      if_nz  call      #SndPACKET              'If it is not clear, then send a packet

              rdlong    t0,     par        wz   'Check for a command being present
        if_z  jmp       #CmdWait                'If there is no command, jump to check again

              mov       t1,     t0              'Move the address of the command
              rdlong    paramA, t1              'Get parameter A value
              add       t1,     #4              'Increment the address pointer by four bytes
              rdlong    paramB, t1              'Get parameter B value
              add       t1,     #4              'Increment the address pointer by four bytes
              rdlong    paramC, t1              'Get parameter C value
              add       t1,     #4              'Increment the address pointer by four bytes
              rdlong    paramD, t1              'Get parameter D value

              shr       t0,     #16        wz   'Get the command
              cmp       t0,     #(_BlankChain>>16)+1 wc 'Check for valid command
  if_z_or_nc  jmp       #:CmdExit               'Command is invalid so exit loop
              shl       t0,     #1              'Shift left, multiply by two
              add       t0,     #:CmdTable-2    'add in the "call" address"
              jmp       t0                      'Jump to the command

              'The table of commands that can be called                
:CmdTable     call      #Buffersetup            'Set up the buffer parameters
              jmp       #:CmdExit
              call      #EnableChain            'Turn on/off the A6281 OEI
              jmp       #:CmdExit
              call      #UpdateChain            'Send data out to the chain of A6281
              jmp       #:CmdExit
              call      #BlankChain             'Send all zeros to the chain of A6281
              jmp       #:CmdExit
:CmdTableEnd  

              'End of processing a command
:CmdExit      wrlong    _zero,  par             'Clear the command status
              jmp       #CmdWait                'Go back to waiting for a new command
              
'-----------------------------------------------------------------------------------------------------
'Command sub-routine to set up the buffer location and size
'-----------------------------------------------------------------------------------------------------
Buffersetup

              mov       pixelBuffer, paramA     'Copy over the start address of the pixel buffer
              mov       pixels, paramB          'Copy over the quantity of pixels in a chain
              mov       latchDelay, paramC      'Copy over the Latch delay time value

Buffersetup_ret ret

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to turn on/off the A6281 OEI
'-----------------------------------------------------------------------------------------------------
EnableChain

              tjnz      paramA, #:enable        'Check if the oei should be enabled or disabled

:disable      or        outa,   oeiMask         'Turn on the A6281 oei (blank)
              jmp       #EnableChain_ret        'End the routine

:enable       andn      outa,   oeiMask         'Turn off the A6281 oei (outputs follow the PWM data)              

EnableChain_ret ret

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to send data out to the chain of A6281
'-----------------------------------------------------------------------------------------------------
UpdateChain
              mov       t1,     pixels          'Get the number of pixels to loop through
              mov       t2,     pixelbuffer     'Get the buffer starting address

:pixelloop    rdlong    txdata, t2              'Read a long out of the buffer in HUB RAM
'             add       t2,     #4              'Increment the address by four bytes
              sub       t2,     #4

              call      #SndA6281Packet         'Clock the data out

              djnz      t1,     #:pixelloop     'Send another pixel if there is another one to send

              'Add time delay here?

              or        outa,   oeiMask         'Blank the A6281 outputs
              
              or        outa,   liMask          'Latch in the data from the shift register

              'add time delay here?
              
              andn      outa,   liMask          'Turn off the latch
              
              andn      outa,   oeiMask         'Reenable the A6281 outputs

UpdateChain_ret ret

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to send all zeros out to the chain of A6281
'-----------------------------------------------------------------------------------------------------
BlankChain
              mov       t1,     pixels          'Get the number of pixels to loop through
              mov       txdata, #0              'Load the data with all zeros

:pixelloop    call      #SndA6281Packet         'Clock the data out

              djnz      t1,     #:pixelloop     'Send another pixel if there is another one to send

              'Add time delay here?

              or        outa,   oeiMask         'Blank the A6281 output
              
              or        outa,   liMask          'Latch in the data from the shift register

              'add time delay here?
              
              andn      outa,   liMask          'Turn off the latch
              
              andn      outa,   oeiMask         'Reenable the A6281 outputs

BlankChain_ret ret

'-----------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------
'Sub-routine to send a packet of data to the A6281
'-----------------------------------------------------------------------------------------------------
SndA6281Packet

:long         mov       txbits, #32             'Prepare to loop for sending 32 bits (one long per A6281)

:bits         shl       txdata, #1         wc   'Move the MSbit into the C register to check for a zero or one
              muxc      outa,   sdiMask         'Set the data bit high or low

              or        outa,   ciMask          'Turn the clock on (clocks in a bit on the A6281)
              
              andn      outa,   ciMask          'Turn the clock off 

              djnz      txbits, #:bits          'Check if another bit to send

SndA6281Packet_ret ret                          'Return to the calling loop

'-----------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------   
'Defined data
_zero         long      0       'Zero

'-----------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------   
'Uninitialized data
t0            res 1     'temp0
t1            res 1     'temp1
t2            res 1     'temp2

paramA        res 1     'Parameter A
paramB        res 1     'Parameter B
paramC        res 1     'Parameter C
paramD        res 1     'Parameter D

ciPin         res 1     'A6281_ClockIn pin
sdiPin        res 1     'A6281_SerialDataIn pin
liPin         res 1     'A6281_LatchIn pin
oeiPin        res 1     'A6281_OutputEnableIn pin

ciMask        res 1     'A6281_ClockIn mask
sdiMask       res 1     'A6281_SerialDataIn mask
liMask        res 1     'A6281_LatchIn mask
oeiMask       res 1     'A6281_OutputEnableIn mask

pixelBuffer   res 1     'Starting address of pixel buffer
pixels        res 1     'Number of pixels in a chain
latchDelay    res 1     'Lenght of time to delay before latching to ensure propogation of clock/data

txdata        res 1     'Buffer of data to be sent - a working buffer
txbits        res 1     'Counter of bits clocked out

fit

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}