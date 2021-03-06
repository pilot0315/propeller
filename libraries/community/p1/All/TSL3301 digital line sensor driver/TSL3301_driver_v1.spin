con ''start of TSL3301 code.
{{

┌──────────────────────────────────────────┐
│ TSL3301_driver_v1                        │
│ Author: Marty Lawson                     │               
│ Copyright (c) 2012 Marty Lawson          │               
│ See end of file for terms of use.        │                
└──────────────────────────────────────────┘

  Note: the assembly code talks to the TSL3301 at up to 10MHz.
  If the TSL3301 is more than 1 inch away from the propeller,
  you must properly terminate the cable to the TSL3301 or else operation will be erratic. }}
                                         
  SDIN = 1      'Prop IO pin hooked to the TSL3301 SDIN pin
  SDOUT = 0     'Prop IO pin hooked to the TSL3301 SDOUT pin
  SCLK = 2      'Prop IO pin hooked to the TSL3301 SCLK pin
  Q_sw_sync = 24
  sync_pin = Q_sw_sync          'set to some value > 31 to disable triggered operation (!untested!)
  
  
var
  {fixed format}
  long Coms_cmd                 '0, ASM done with current cmd.  1 update gain and offset. 2 grab a new frame. 3 update integration time.  4 update trigger delay.  5 reset TSL3301, 6 debug TSL3301 coms
  long gain_code                'valid range 0 to 31            (enforced by spin wrapper)
  long offset                   '8-bit sign magnitude encoding. (enforced by spin wrapper)          
  long int_time                 '[clocks] must be a value greater than 20 (read before each frame)
  long trigger_delay            '[clocks] time to delay after trigger before initiating integration of a line (read before each frame)
  long int_measured             '[clocks] between end of integration start and end commands
  long readout_measured         '[clocks] from integratin end to readout of last byte
  byte line_data[102]           'byte array containing line data  (don't change anything before this without updating the offset_line_ptr constant)
  {/fixed format}

con
  offset_line_ptr = 28          'address offset between Line_data and Coms_cmd.  

pub start(of_set,GC) : temp
  {{initial setup of the TSL3301 and ASM}}
  coms_cmd := 0                                         'initialise to no action                
  temp := cognew(@TSL3301entry, @Coms_cmd) + 1           'start ASM code 
  ResetTSL3301                                          'reset the TSL3301 to a known state
  SetGains(of_set,GC)                                      'offset, gain of TSL3301 PGA
  SetIntegration(1000)                         'set how long to integrate a frame [clocks > 157]
  SetTrigDly(6)                          'set how long to delay start of integration after trigger event.

pub CaptureFrame
{{initiate triggered capture of a new line to main memory.  Returns address of line data buffer}}  
  Coms_cmd := 2      'tell ASM to get a new frame
  repeat while Coms_cmd 'wait for ASM to signal it's done
  result := @Line_data

pub GetFrameData(destination_addr)
{{transfer line data from the driver's buffer to a BYTE buffer somewhere else in memory}}
  bytemove(destination_addr, @line_data, 102)

pub GetFrameDataLong(destination_addr) | temp
{{transfer line data from the driver's buffer to a LONG buffer somewhere else in memory}}
  repeat temp from 0 to 101
    long[destination_addr][temp] := byte[@line_data][temp]

Pub ResetTSL3301
{{tell ASM to reset the TSL3301 to a known state}}
  coms_cmd := 5                                         'tell ASM to reset the TSL3301 {code below should be moved to Set_gains, Set_integration, Reset_TSL301, and Set_trig_dly subs}
  repeat while coms_cmd                                 'wait for ASM to finish

pub SetTrigDly(dly)
{{set a new trigger delay.  trigger delay is in units of clocks.  Min value of 6 after ~40 clocks of overhead has been subtracted}}
  trigger_delay := (dly-40) #> 6                             'limit to valid values
  coms_cmd := 4                                         'flag telling ASM to load trigger delay
  repeat while coms_cmd                                 'confirm completion of setup.  loop while coms_cmd != 0

pub SetIntegration(int)
{{set the number of clocks to integrate one line for.  Min value of 163 clocks.  I.e. 157 clocks of overhead plus a 6 clock minimum delay}}
  int_time := (int - 157) #> 6
  coms_cmd := 3                                         'flag telling ASM to load integration time
  repeat while coms_cmd                                 'confirm completion of setup.  loop while coms_cmd != 0    

pub SetGains(off, GC)
{{setup the TSL3301 gain and offset registers to appropriate values with bounds checking}}
  gain_code := 0 #> GC <# 31           'limit the gain codes to a valid range
  if off < 0                 'if offset is negative
    off := ||off          'start converting to sign magnitude by taking the absolute value
    off &= $7F               'limit to 7-bit magnitude
    off |= $80               'set sign bit
  else
    off &= $7F               'otherwise just limit to 7-bits of magnitude and clear sign bit
  offset := off
  coms_cmd := 1                                         'flag telling ASM to load gains and offsets
  repeat while coms_cmd                                 'confirm completion of setup.  loop while coms_cmd != 0                             

pub get(idx)
{{public function to read the privite variable space of the driver.
Most useful to read the two timing variables.
idx is the long alligned location of the variable in the Var block at the top of the code
i.e. Get(0) == coms_cmd and Get(5) == int_measured}}
  idx := 0 #> idx <# (@readout_measured - @coms_cmd)/4
  result := long[@coms_cmd][idx]

  

DAT
              org     0                         'start ASM code address counter
'initialization, only run once.  This space can be re-used as vairable space if needed.  
TSL3301entry  or        dira,   SDIN_mask       'setup output pins
              or        dira,   SCLK_mask
              mov       ctra,   SCLK_ctrx       'setup nco mode on SCLK pin
              mov       frqa,   #1              'count by 1
              mov       ctrb,   SDIN_ctrx       'setup to output bits with ROR
              mov       frqb,   #0              'don't count
              mov       phsb,   #0
              'absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse                                                                                                                       
'command dispatch loop
cmd_dis       rdlong    command, PAR            'read in command
              tjz       command, #cmd_dis       'block untill a nonzero command is seen
              cmp       command, #2             wz      'if command is equal to 2 set Z
        if_z  call      #capture_frame                  'capture a frame (most time sensative)
              cmp       command, #1             wz
        if_z  call      #set_gain_asm                   'set gains
              cmp       command, #3             wz
        if_z  call      #set_int                        'set integration time
              cmp       command, #4             wz
        if_z  call      #set_trig_dly                   'set frame trigger delay
              cmp       command, #5             wz
        if_z  call      #rst_TSL3301                    'reset the TSL3301
              cmp       command, #6             wz
        if_z  call      #debug                          'debug communication problems
cmd_dis_exit  mov       command, #0                     'All commands done, prepare to clear command in HUB.  label added to support jump table or "goto" bassed code
              wrlong    command, PAR            'clear command in HUB to flag that I've completed the command
              mov       phsa,   #0              'clear phsa ocassionally to prevent stray clock pulses.
              jmp       #cmd_dis                'jump to command wait                                            

'debug command.  do whatever is needed here to figure out what's wrong.  right now does a write and readback command.  Found my INA in destination error.  
debug         mov       line_hub_ptr,  PAR      'setup pointer to line dat in hub.  
              add       line_hub_ptr,  #offset_line_ptr
              mov       temp1, #$40             'write left offset
              call      #send_asm
              mov       temp1,  #%1010_1010     'write junk to left offset
              call      #send_asm
              mov       temp1,  #10             'insure write is complete
:loop1        absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              djnz      temp1,  #:loop1              
              mov       temp1,  #$60            'read left offset
              call      #send_asm
:loop3        test      SDOUT_mask, ina         wz          'wait for SDOUT_mask to go low 'INA is a read only register so can only read true value via source of instruction
        if_z  jmp       #:read                  'if SDOUT pin is low jump to readout
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              jmp       #:loop3                 'go back and test if SDOUT pin is low again              
:read         call      #rcv                    'read back the register data
              wrbyte    temp1,  line_hub_ptr    'write out readback results.              
debug_ret     ret



'code to capture a frame
capture_frame mov       line_hub_ptr,  PAR
              add       line_hub_ptr,  #offset_line_ptr             'temp1 is a pointer to the start of the data array in hub
              
              'start integration.  
              mov       temp1,  #$08            'command to start integration
              call      #send_asm

              mov       temp1,  #19             'pulse the clock pin 19 of 21 times.  ~10MHz with an 80MHz main clock
:loop1        absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              djnz      temp1,  #:loop1

              mov       temp1,  trig_clk         'place one waitcnt setup instruction in a less time critical location as 50nS does matter
              waitpeq   Q_sw_mask, Q_sw_mask     'wait for High level on Sync pin
              add       temp1,  CNT              'delay start of line frame 
              waitcnt   temp1,  #0  '}

              absneg    phsa,   #4              'pulse the clock pin last 3 times.  ~10MHz with an 80MHz main clock
              nop      
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              nop               
              absneg    phsa,   #4              'need 3 clocks after wait for consistent exposure
              'grab cnt for profiling
              mov       cnt1,   cnt             
              'wait integration time
              mov       temp1,  int_clk         'add a block comment to the start of this line to take minimum length frames 152 [clock] or 1.9 [uS]
              add       temp1,  CNT
              waitcnt   temp1,  #0              '}
              'end integration
              mov       temp1,  #$10            'stage end integration command
              call      #send_asm               'send end integration command to TSL3301
              mov       temp1,  #5              'pulse the clock pin 5 times to complete frame end command.  ~10MHz with an 80MHz main clock
:loop2        absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              djnz      temp1,  #:loop2         'integration ends sometime during these clocks.  (rising edge of last clock?)
              mov       cnt2,   cnt             'grab cnt of frame end
              'start pixel readout              '
              mov       temp1,  #$02            'command to start pixel readout
              call      #send_asm
              test      SDOUT_mask, ina          wz          'wait for SDOUT_mask to go low
        if_z  jmp       #:read                  'if SDOUT pin is low jump to readout
:loop5        absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse              
              test      SDOUT_mask, ina         wz
        if_nz jmp       #:loop5                 'pulse clock again till SDOUT is low                   
              'read 102 pixels
:read         mov       pixel_idx, #25         'setup for 100 of 102 pixels in blocks of 4 pixels   
:loop4        call      #rcv                    'recieve a pixel value in bits 0-7 of temp1
              mov       temp2,  #0              'clear accumulator word
              or        temp2,  temp1           'put result in lower bits 0-7
              call      #rcv                    'recieve a pixel value in bits 0-7 of temp1
              shl       temp1,  #8              'rotate result into bits 8-15
              or        temp2,  temp1           'add results
              call      #rcv                    'recieve a pixel value in bits 0-7 of temp1
              shl       temp1,  #16             'rotate result into bits 16-23
              or        temp2,  temp1           'add results
              call      #rcv                    'recieve a pixel value in bits 0-7 of temp1
              shl       temp1,  #24             'rotate result into bits 24-31
              or        temp2,  temp1           'add results
              wrlong    temp2,  line_hub_ptr    'write pixel to HUB (MUST be LONG alligned)
              add       line_hub_ptr, #4        'increment to next byte in hub
              djnz      pixel_idx, #:loop4
              'read last 2 pixels
              call      #rcv                    'recieve a pixel value in bits 0-7 of temp1
              wrbyte    temp1,  line_hub_ptr    'write pixel to HUB (MUST be LONG alligned)
              add       line_hub_ptr, #1        'increment to next byte in hub
              call      #rcv                    'recieve a pixel value in bits 0-7 of temp1
              wrbyte    temp1,  line_hub_ptr    'write pixel to HUB (MUST be LONG alligned)                                                                   
              mov       cnt3,   cnt             'cnt of readout end
              'add timing commands, and debug variable writes here
              sub       cnt3,   cnt2            'cnt3 - cnt2 = readout time. (looks like 13734 [clocks] or 172uS of overhead) 
              sub       cnt2,   cnt1            'cnt2 - cnt1 = frame length. (looks like 157 [clocks] of overhead ~1.96uS)
              'write to hub variables.
              mov       temp1,  par
              add       temp1,  #20
              wrlong    cnt2,   temp1           'PAR + 20 integration_length
              add       temp1,  #4
              wrlong    cnt3,   temp1           'PAR + 24 readout_time               
capture_frame_ret ret



'code to recieve pixel values (unrolled faster loop ~6.7MHz) 
rcv           'mov       temp1,  #10              'clear result variable
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              test      SDOUT_mask, ina          wc
              rcr       temp1,  #1              'rotate C into MSB
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              test      SDOUT_mask, ina          wc
              rcr       temp1,  #1              'rotate C into MSB
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              test      SDOUT_mask, ina          wc
              rcr       temp1,  #1              'rotate C into MSB
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              test      SDOUT_mask, ina          wc
              rcr       temp1,  #1              'rotate C into MSB
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              test      SDOUT_mask, ina          wc
              rcr       temp1,  #1              'rotate C into MSB
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              test      SDOUT_mask, ina          wc
              rcr       temp1,  #1              'rotate C into MSB
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              test      SDOUT_mask, ina          wc
              rcr       temp1,  #1              'rotate C into MSB
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              test      SDOUT_mask, ina          wc
              rcr       temp1,  #1              'rotate C into MSB
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              shr       temp1,  #24             'shift input value to lower byte of temp1
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse              
rcv_ret       ret
''can I do this with a free-running counter as the clock?  (would cut ~7 instructions for 10MHz bursts)  Or would conditional counter modes work better?
''consider making a combined send_rcv_asm function when switching to a free-running clock.  (would also require me to change how I use phsa to generate extra clock pulses)


'code to set gains
set_gain_asm  mov       temp1,  PAR
              add       temp1,  #4
              rdlong    temp2,  temp1           'temp2 is the gain_code to write to the TSL3301
              add       temp1,  #4
              rdlong    temp3,  temp1           'temp3 is now the offset to write to the TSL3301
              'talk to the TSL3301 an update all the gains.
              mov       temp1,  #$40            'left offset
              call      #send_asm
              mov       temp1,  temp3           'value of left offset
              call      #send_asm
              mov       temp1,  #$41            'left gain
              call      #send_asm
              mov       temp1,  temp2           'value of left gain
              call      #send_asm
              mov       temp1,  #$42            'center offset
              call      #send_asm
              mov       temp1,  temp3           'value of center offset
              call      #send_asm
              mov       temp1,  #$43            'center gain
              call      #send_asm
              mov       temp1,  temp2           'value of center gain
              call      #send_asm
              mov       temp1,  #$44            'right offset
              call      #send_asm
              mov       temp1,  temp3           'value of right offset
              call      #send_asm
              mov       temp1,  #$45            'right gain
              call      #send_asm
              mov       temp1,  temp2           'value of right gain
              call      #send_asm              
set_gain_asm_ret  ret


'code to set integration time
set_int       mov       temp1,  PAR
              add       temp1,  #12             'advance three longs in byte addresses
              rdlong    int_clk, temp1          'read in new integration time length
set_int_ret   ret

'code to set frame trigger delay
set_trig_dly  mov       temp1,  PAR
              add       temp1,  #16             'advance four longs in byte addresses
              rdlong    trig_clk, temp1         'read in new trigger hold off time length
set_trig_dly_ret  ret

'code to reset TSL3301 chip
rst_TSL3301   andn      outa,   SCLK_mask       'clear clock pin
              andn      outa,   SDIN_mask       'clear data to sensor pin
              mov       temp1,  #30             'pulse the clock pin 30 times.  ~10MHz with an 80MHz main clock
:loop1        absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              djnz      temp1,  #:loop1
              or        outa,   SDIN_mask       'set data to sensor pin
              mov       temp1,  #10             'pulse the clock pin 10 times
:loop2        absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              djnz      temp1,  #:loop2
              mov       temp1,  #$1B            'move reset command into temp variable
              call      #send_asm                    'send reset cmd to chip.
              mov       temp1,  #5              'pulse the clock pin 5 times to complete reset command     
:loop3        absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              djnz      temp1,  #:loop3
              mov       temp1,  #$5F            'write mode register command
              call      #send_asm
              mov       temp1,  #$00            'clear mode register
              call      #send_asm              
rst_TSL3301_ret   ret

'send a byte to the TSL3301 ~10MHz baud rate.  temp1 is input variable,  
send_asm      andn      outa,   SDIN_mask       'clear SDIN. start bit
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              mov       phsb,   temp1           'move data into phsb (bit 31 should be cleared to avoid a data line glitch)
:loop         ror       phsb,   #1              'rotate lsb into bit31 and output
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              ror       phsb,   #1              'rotate lsb into bit31 and output
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              ror       phsb,   #1              'rotate lsb into bit31 and output
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              ror       phsb,   #1              'rotate lsb into bit31 and output
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              ror       phsb,   #1              'rotate lsb into bit31 and output
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              ror       phsb,   #1              'rotate lsb into bit31 and output
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              ror       phsb,   #1              'rotate lsb into bit31 and output
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              ror       phsb,   #1              'rotate lsb into bit31 and output
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
              or        outa,   SDIN_mask       'set SDIN. stop bit
              mov       phsb,   #0              '"stop" counter 
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
send_asm_ret      ret

{pulse SCLK
              absneg    phsa,   #4              'set phsa to -4.  Generates a 4 [clock] pulse
}

              
SDIN_mask     long      |< SDIN     'eliminate any 0-0 variables set from spin when making an object from this code.
SDOUT_mask    long      |< SDOUT     'this will make the object more language portable.
SCLK_mask     long      |< SCLK
Q_sw_mask     long      |< sync_pin            'mask for pin to trigger on
SCLK_ctrx     long      %00100 << 26 + SCLK     'setup counter mode for generating clock pulses
SDIN_ctrx     long      %00100 << 26 + SDIN     'setup counter mode to ROR data out on SDIN
command       res       1
int_clk       res       1       'duration of frame integration in clocks
trig_clk      res       1       'trigger hold off in clocks
line_hub_ptr  res       1       'pointer to the start of the frame storage space in HUB
temp1         res       1       'used for parameter passing to subs, and scratch var
temp2         res       1       'scratch var.  generally don't live past sub calls.
temp3         res       1       'scratch var
pixel_idx     res       1       'index variable for pixel read loop
cnt1          res       1      'timing variables for code timing profiling.  
cnt2          res       1
cnt3          res       1

              fit       496                     'fire off a compiler error if ASM code is too big.


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