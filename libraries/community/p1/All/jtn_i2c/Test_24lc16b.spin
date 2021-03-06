{{ 
  Title:
    Test_24lc16b Demo Program
   
  Author:
    Jim Newman
 
  Version:
    1.0                         Initial Release
   
  Revision History:  
    1.0         06/16/2011      Initial Release 
    
  Description:
  This is a demonstration program for the i2c bus driver that uses a 24lc16b
  eeprom.

  The intent of this demonstration program is to show how to use the i2c bus
  driver.  It attempts to demonstrate the use of each of the i2c methods.

  This program uses the 24lc16b driver that uses the i2c driver.  It also
  uses the FullDuplexSerial driver to display the results on a PC.

  Test Circuit:
                          3.3V         3.3V
                                       
                          ┌┴┐           │  
           ┌───────┐        ┌───────┐ │ 
           │     P0├──────┻─┼─┤SCL Vcc├─┘  
           │     P1├────────┻─┤SDA    │   
           │       │          │       │ 
           │       │        ┌─┤Wp  Vss├─┐ 
           └───────┘         └───────┘ 
             Prop              24lc16b  

  Hardware Setup:
  This was tested using the Propeller Demo Board.  The 24lc16b was inserted
  into the solder less breadboard portion of the board and wired as described
  above.  The Demo Board was then connected to a PC by was of a USB cable.
  An appropriate wall-wart was then connected to the Demo Board and power was
  turned on by closing the On/Off switch.

  Software Setup:
  This demonstration program requires three files; Test_24lc16b.spin (this file),
  24lc16b.spin and I2C.spin.  File Test_24lc16b.spin was then loaded into
  Propeller Tool from the directory containing all three files.  The program was
  then verified by pressing the F9 key.

  Running the Demo:
  You will first need to set up the hardware and software as described above.
  Then bring up Propeller Serial Terminal.  You will need to connect the serial
  terminal to the appropriate Com Port and set the Baud Rage to 9600.  Then load
  the program into the Demo Board by either pressing F10 or F11.  Quickly switch
  over the serial terminal and enable it by pressing the Enable button.  If
  everything goes right, you should see the following output displayed on the
  serial terminal:

  Start of test

  Test single byte write
  Writing address 0, data 0
  Writing address 1, data 1
  Writing address 2, data 2
  Writing address 3, data 3
  Writing address 4, data 4
  Writing address 5, data 5
  Writing address 6, data 6
  Writing address 7, data 7
  Writing address 8, data 8
  Writing address 9, data 9
  Writing address 10, data 10
  Writing address 11, data 11
  Writing address 12, data 12
  Writing address 13, data 13
  Writing address 14, data 14
  Writing address 15, data 15
   
  Test single byte read
  address = 0, read = 0
  address = 1, read = 1
  address = 2, read = 2
  address = 3, read = 3
  address = 4, read = 4
  address = 5, read = 5
  address = 6, read = 6
  address = 7, read = 7
  address = 8, read = 8
  address = 9, read = 9
  address = 10, read = 10
  address = 11, read = 11
  address = 12, read = 12
  address = 13, read = 13
  address = 14, read = 14
  address = 15, read = 15
   
  Test block write
   
  Test block read
  address = 244, read = 0
  address = 245, read = 0
  address = 246, read = 0
  address = 247, read = 0
  address = 248, read = 1
  address = 249, read = 2
  address = 250, read = 3
  address = 251, read = 4
  address = 252, read = 5
  address = 253, read = 6
  address = 254, read = 7
  address = 255, read = 8
  address = 256, read = 9
  address = 257, read = 10
  address = 258, read = 11
  address = 259, read = 12
  address = 260, read = 13
  address = 261, read = 14
  address = 262, read = 15
  address = 263, read = 16
  address = 264, read = 0
  address = 265, read = 0
  address = 266, read = 0
  address = 267, read = 0
  address = 268, read = 0
  address = 269, read = 0
  address = 270, read = 0
  address = 271, read = 0
  address = 272, read = 0
  address = 273, read = 0
  address = 274, read = 0
  address = 275, read = 0
  End of Test

}}

CONN
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  scl = 0
  sda = 1
  i2c_freq = 400_000

VAR
  long data_blk[16]        
  
OBJ
  term    : "FullDuplexSerial"
  mem     : "24lc16b"

PUB test_24lc16b | i, temp, addr_cnt, my_data, start_addr, stop_addr, my_ack, my_cnt

  term.start(31, 30, 0, 9600) 
  waitcnt(80_000_000*3 + cnt)
  
  term.str(string("Start of test", 13))                 ' give our self a header
   
  mem.start(scl, sda, i2c_freq)                         ' initialize the eeprom driver

  ' start of single byte write and single byte read
                                                        
  start_addr := $00                                     ' set the starting address of memory 
  stop_addr := start_addr + $0f  
                                                        
  ' Test single byte write  
  term.str(string(13, "Test single byte write", 13))    ' tell user what we're doing
  my_data := $00                                        ' set starting value for data to be written
  repeat addr_cnt from start_addr to stop_addr
    term.str(string("Writing address "))                ' tell user what we're writing
    term.dec(addr_cnt)
    term.str(string(", data "))
    term.dec(my_data)
    term.tx(13)       
    mem.write_byte(addr_cnt, my_data)                   ' write data to memory address
    my_data += 1                                        ' increment data

  ' Test single byte read 
  term.str(string(13, "Test single byte read", 13))     ' tell user what we're doing
  repeat addr_cnt from start_addr to stop_addr 
    my_data := mem.read_byte(addr_cnt)                  ' read data from memory address
    term.str(string("address = "))                      ' tell user what we read
    term.dec(addr_cnt)
    term.str(string(", read = "))
    term.dec(my_data)   
    term.tx(13)

  ' Start of block write and block read tests.
                   
  repeat i from $000 to $1ff    ' clear all of the memory with single byte writes
    mem.write_byte(i, 0)

  start_addr := $0f8            ' let's make sure we go over a 256 byte boundary
  my_cnt := 16

  repeat i from 0 to 15         ' write some data into the block of data to write
    data_blk[i] := i + 1
                                                        
  term.str(string(13, "Test block write", 13))          ' let's tell the user what we're doing 
  mem.write_block(start_addr, @data_blk, 16)            ' write the block of data

  ' Test block read 
  term.str(string(13, "Test block read", 13))           ' and some for information for the user
  
  start_addr -= 4             ' let's read a few extra addresses on each end of the memory that we wrote

  repeat 2
    repeat i from 0 to 15     ' clear the buffer to make sure we've actually read the memory into it
      data_blk[i] := 0
                    
    mem.read_block(start_addr, @data_blk, 16)           ' read the block of memory

    repeat i from 0 to 15
      term.str(string("address = "))                    ' print out what we read so the user can see it
      term.dec(start_addr + i)
      term.str(string(", read = "))
      term.dec(data_blk[i])                             
      term.tx(13)                                       ' let's read the next 16 locations
    start_addr += 16                

  term.str(string("End of Test", 13))                
         
  repeat
 

{{

Copyright(c) 2011 - Jim Newman

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
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

}}