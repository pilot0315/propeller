'' ******************************************************************************
'' * I2CKeyPad object utilizing MCP23008 I/O expander chip                      *
'' * Ron Czapala April 2014                                                     *
'' * Version 1.0                                                                *
'' ******************************************************************************
{{
This object uses the Interrupt-On-Change feature of the Microchip MCP23008 I/O Expander chip to interface a 4x4 Matrix Keypad (Parallax #27899) to a propeller MCU.
See Microchip's Application Note AN1081 at http://ww1.microchip.com/downloads/en/AppNotes/01081a.pdf
When a key on the keypad is pressed, the MCP23008 goes LOW and the propeller scans the rows and columns to determine which key is pressed.
Then it clears the interrupt as the key is released.


             ┌───┐   ┌───┐   ┌───┐   ┌───┐
        ┌────┫ 1 ┣───┫ 2 ┣───┫ 3 ┣───┫ A │
        │    └─┳─┘   └─┳─┘   └─┳─┘   └─┳─┘
        │    ┌─┻─┐   ┌─┻─┐   ┌─┻─┐   ┌─┻─┐  K
        │ ┌──┫ 4 ┣───┫ 5 ┣───┫ 6 ┣───┫ B │  E
        │ │  └─┳─┘   └─┳─┘   └─┳─┘   └─┳─┘  Y
        │ │  ┌─┻─┐   ┌─┻─┐   ┌─┻─┐   ┌─┻─┐  P
        │ │ ┌┫ 7 ┣───┫ 8 ┣───┫ 9 ┣───┫ C │  A
        │ │ │└─┬─┘   └─┬─┘   └─┬─┘   └─┬─┘  D
        │ │ │┌─┻─┐   ┌─┻─┐   ┌─┻─┐   ┌─┻─┐
        │ │ ││ * ┣───┫ 0 ┣─┳─┫ # ┣───┫ D │
        │ │ │└─┳─┘   └─┳─┘ │ └─┳─┘   └─┳─┘
        │ │ │  │       │   │   └─┐ ┌───┘
        │ │ │  │       └───┼───┐ │ │
        │ │ │  └───────────┼─┐ │ │ │
        │ │ └────────────┐ │ │ │ │ │
        │ └────────────┐ │ │ │ │ │ │
        └────────────┐ │ │ │ │ │ │ │
                     8 7 6 5 4 3 2 1
            ┌──────┫ │ │ │ │ │ │ │
            ┣──────┼─┫ │ │ │ │ │ │    
        10k ┣──────┼─┼─┫ │ │ │ │ │
            ┣──────┼─┼─┼─┫ │ │ │ │   
            ┣──────┐ │ │ │ │ │ │ │ │   
            │    ┌─┴─┴─┴─┴─┴─┴─┴─┴─┴─┐   ─ GP7 thru GP0 (GP7 thru GP4 are pulled high with 10K resistors)
            │    │ +                 │
            │    │                   │
            │    │•    MCP23008      │
            │    │                   │
            │    │                 - │
            │    └─┬─┬─┬─┬─┬─┬─┬─┬─┬─┘
            │      S S A A A R   I │
            │      C D 2 1 0 E   N │
            │      L A │ │ │ S   T │
            │      │ │ └─┻─┻─┼───┼─┻────VSS
            └─┳────┼─┼────┳──┻───┼──────VDD
              └──┫ ┣──┘      │      3.3V
               4.7k│ │4.7k       │
                   │ │           │
                   
                    Propeller pins     


MCP23008    P8X32A          KEYPAD
1  SCL        28
2  SDA        29
3  A2        VSS
4  A1        VSS
5  A0        VSS
6  RESET     VDD (3.3V)
7  NC
8  INT         0
9  VSS       VSS
10 GP0                      1  col 4
11 GP1                      2  col 3
12 GP2                      3  col 2
13 GP3                      4  col 1
14 GP4                      5  row 4
15 GP5                      6  row 3
16 GP6                      7  row 2
17 GP7                      8  row 1 
18 VDD       VDD (3.3V)

GP4 thru GP7 are pulled high to 3.3V with 10K resistors

}}
CON
  _clkmode      = xtal1 + pll16x
  _xinfreq      = 5_000_000

  CLK_FREQ = ((_clkmode - xtal1) >> 6) * _xinfreq               ' system freq as a constant
  MS_001   = CLK_FREQ / 1_000                                   ' ticks in 1ms
  US_001   = CLK_FREQ / 1_000_000                               ' ticks in 1us 
  
VAR
  byte cog                 

  long MCP23008_Address
  long keycharaddr

  word  i2cSDA, i2cSCL, interrupt 

  long Stack[38]
  
OBJ
  MCP23008Object : "MCP23008Object"

PUB Init(_deviceAddress, _i2cSDA, _i2cSCL, _driveSCLLine, _interrupt, _keycharaddr): okay
' init the Object

  mcp23008_Address := _deviceAddress
  i2cSDA := _i2cSDA
  i2cSCL := _i2cSCL
  interrupt := _interrupt
  keycharaddr := _keycharaddr

  cog := cognew(Start, @Stack) + 1
  okay := cog
  return okay
  
PUB Start
  dira[interrupt] ~     'set interrupt pin to input
  
  ' setup the MCP32008 I/O Expander
  MCP23008Object.init(MCP23008_Address, i2cSDA, i2cSCL, true)    'drive SCL
  MCP23008Object.WriteReg(MCP23008Object#_MCP23008_GPPU, %0000_1111)      ' 100k internal resistors disabled for rows, enabled for columns (rows uses external resistors SEE AN1081)
  MCP23008Object.WriteReg(MCP23008Object#_MCP23008_GPIO, %0000_0000)      ' write to device mcp23008_write MCP23008, rows are inputs, columns are outputs
  Setup_IO

  repeat
    waitpeq(%0, %1, 0)                 'Wait for P0 to be low (interrupt from MCP23008)
    byte[keycharaddr] := KeyScan       'store KeyPad char into address passed to Init
    
PRI KeyScan : Result | rows, cols, keycode, index
    rows := mcp23008Object.ReadReg(mcp23008Object#_MCP23008_INTCAP)       ' determine rows
    Swap_IO                                                               ' reconfigure registers to read columns 
    cols := mcp23008Object.ReadReg(mcp23008Object#_MCP23008_GPIO)         ' determine columns
    keycode := rows | cols
    index := lookdownz(keycode: $77, $7B, $7D, $7E, $B7, $BB, $BD, $BE, $D7, $DB, $DD, $DE, $E7, $EB, $ED, $EE)
                           '
    Result := keychar[index]
    Setup_IO
    Waitfor_Key_Release
    return Result

PRI Setup_IO | tmp
'configure registers to read rows

  MCP23008Object.WriteReg(MCP23008Object#_MCP23008_IODIR, %1111_0000)     ' write to device mcp23008_write MCP23008, rows are inputs, columns are outputs
  MCP23008Object.WriteReg(MCP23008Object#_MCP23008_INTCON, %1111_0000)    ' interrupt-on-change pins - set for rows, cleared for columns
  MCP23008Object.WriteReg(MCP23008Object#_MCP23008_DEFVAL, %1111_0000)    ' interrupt-on-change default values - set for rows, cleared for columns
  MCP23008Object.WriteReg(MCP23008Object#_MCP23008_GPINTEN, %1111_0000)   ' interrupt-on-change - enable rows (must be set last)
    
PRI Swap_IO
'configure registers to read columns

' IODIR: The IODIR register has its value switched so that the rows are now outputs and the columns inputs.
' INTCON/DEFVAL/GPINTEN: These registers which control the interrupt-on-change feature also all have their values switched.
' The interrupt-on-change feature is not used for reading of the columns. But if left in its original setup, when the IODIR register has
' it's value changed from 0xF0 to 0x0F and the GPIO register is then read to obtain the column
' value (explained in next section) the interrupt will be cleared. Once the IODIR register
' is flipped back to its original setup an interrupt will occur once more.
' To avoid this,the interrupt-on-change register values are also switched.

  MCP23008Object.WriteReg(MCP23008Object#_MCP23008_IODIR, %0000_1111)     ' write to device mcp23008_write MCP23008, rows are outputs, columns are inputs
  MCP23008Object.WriteReg(MCP23008Object#_MCP23008_INTCON, %0000_1111)    ' see comments above
  MCP23008Object.WriteReg(MCP23008Object#_MCP23008_DEFVAL, %0000_1111)    ' see comments above
  MCP23008Object.WriteReg(MCP23008Object#_MCP23008_GPINTEN, %0000_1111)   ' see comments above

PRI Waitfor_Key_Release | tmp 
  repeat
    waitcnt(MS_001 * 5 + cnt)
    tmp := mcp23008Object.ReadReg(mcp23008Object#_MCP23008_INTCAP)       ' read INTCAP to clear interrupt
  until ina[interrupt] == 1

DAT
keychar  byte "1","2","3","A"
         byte "4","5","6","B"
         byte "7","8","9","C"
         byte "*","0","#","D"

{{

  Terms of Use: MIT License

  Permission is hereby granted, free of charge, to any person obtaining a copy of this
  software and associated documentation files (the "Software"), to deal in the Software
  without restriction, including without limitation the rights to use, copy, modify,
  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to the following
  conditions:

  The above copyright notice and this permission notice shall be included in all copies
  or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
  PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
  OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

}}                                            '